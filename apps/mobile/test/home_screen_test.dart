/// 홈 피드 위젯 테스트 (BRU-156). 프리뷰 컨테이너의 인메모리 표본으로
/// iOS `HomeView.swift`의 계약 — 그룹핑·계층·탭 계약·선택 모드·필터·뷰 전환 —
/// 을 검증한다.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app.dart';
import 'package:mobile/environment/drop_environment_container.dart';
import 'package:mobile/environment/providers.dart';
import 'package:mobile/screens/note_detail_screen.dart';
import 'package:mobile/widgets/selection_action_bar.dart';

Widget previewApp() => ProviderScope(
  overrides: [
    dropContainerProvider.overrideWithValue(DropEnvironmentContainer.preview()),
  ],
  child: const DropApp(),
);

Future<void> pumpPreview(WidgetTester tester) async {
  await tester.pumpWidget(previewApp());
  await tester.pumpAndSettle();
}

/// GestureDetector에 onDoubleTap이 있으면 싱글탭 판정이 더블탭 대기만큼
/// 늦어진다 — 탭 뒤에 시간을 흘려 판정을 끝낸다.
Future<void> singleTap(WidgetTester tester, Finder finder) async {
  await tester.tap(finder);
  await tester.pumpAndSettle(const Duration(milliseconds: 400));
}

Future<void> doubleTap(WidgetTester tester, Finder finder) async {
  await tester.tap(finder);
  await tester.pump(const Duration(milliseconds: 80));
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Clipboard.setData가 플랫폼 채널로 보낸 텍스트를 붙잡는다.
List<String> mockClipboard(WidgetTester tester) {
  final copied = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'Clipboard.setData') {
        copied.add((call.arguments as Map)['text'] as String);
      }
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );
  return copied;
}

void main() {
  testWidgets('피드는 고정·날짜 섹션 헤더로 묶인다', (tester) async {
    await pumpPreview(tester);

    expect(find.text('고정'), findsOneWidget);
    expect(find.text('오늘'), findsOneWidget);
    expect(find.text('어제'), findsOneWidget);
  });

  testWidgets('답글은 부모 아래에 들여쓰여 나오고, 부모 잃은 답글은 표시가 붙는다', (tester) async {
    await pumpPreview(tester);

    // 답글(2-1)은 부모(2)와 함께 보인다 — 자기 시각이 아니라 부모의 섹션이다.
    expect(find.text('장보기: 우유, 커피 원두, 사과'), findsOneWidget);
    expect(find.text('원두는 지난번 것으로'), findsOneWidget);
    // 부모가 보관함에 있는 답글(4-1)은 최상위로 올라오되 화살표가 붙는다.
    expect(find.byIcon(Icons.subdirectory_arrow_right), findsOneWidget);
  });

  testWidgets('싱글탭은 뷰어(/note/:id)를 연다 — 읽기 전용 (BRU-77)', (tester) async {
    await pumpPreview(tester);

    await singleTap(tester, find.text('장보기: 우유, 커피 원두, 사과'));

    expect(find.byType(NoteDetailScreen), findsOneWidget);
    expect(find.text('#11'), findsOneWidget);
  });

  testWidgets('더블탭은 본문을 클립보드에 넣는다 (BRU-129)', (tester) async {
    await pumpPreview(tester);
    final copied = mockClipboard(tester);

    await doubleTap(tester, find.text('장보기: 우유, 커피 원두, 사과'));

    expect(copied, ['장보기: 우유, 커피 원두, 사과']);
    // 복사는 화면을 옮기지 않는다.
    expect(find.byType(NoteDetailScreen), findsNothing);
  });

  testWidgets('롱프레스는 선택 모드 — 액션 바가 뜨고 탭은 토글만 한다', (tester) async {
    await pumpPreview(tester);
    final copied = mockClipboard(tester);

    await tester.longPress(find.text('장보기: 우유, 커피 원두, 사과'));
    await tester.pumpAndSettle();

    expect(find.text('1개 선택됨'), findsOneWidget);
    expect(find.byType(SelectionActionBar), findsOneWidget);
    expect(find.text('보관'), findsWidgets);

    // 선택 모드의 싱글탭은 다른 노트를 선택에 더한다 — 뷰어를 열지 않는다.
    await singleTap(tester, find.text('제주 사진 몇 장'));
    expect(find.text('2개 선택됨'), findsOneWidget);
    expect(find.byType(NoteDetailScreen), findsNothing);

    // 더블탭도 토글만 — 복사하지 않는다 (BRU-129).
    await doubleTap(tester, find.text('제주 사진 몇 장'));
    expect(copied, isEmpty);

    // 취소는 선택을 비우고 일반 모드로 돌아간다.
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(find.text('DROP'), findsOneWidget);
    expect(find.byType(SelectionActionBar), findsNothing);
  });

  testWidgets('태그 칩은 목록을 좁히고, 다시 누르면 푼다', (tester) async {
    await pumpPreview(tester);

    // '#생활' 텍스트는 노트 카드의 태그 라벨에도 있다 — 칩만 집는다.
    final chip = find.widgetWithText(FilterChip, '#생활');
    await tester.tap(chip);
    await tester.pumpAndSettle();

    expect(find.text('장보기: 우유, 커피 원두, 사과'), findsOneWidget);
    expect(find.text('제주 사진 몇 장'), findsNothing);

    await tester.tap(chip);
    await tester.pumpAndSettle();
    expect(find.text('제주 사진 몇 장'), findsOneWidget);
  });

  testWidgets('⋯ 메뉴로 휴지통 뷰에 가면 버린 표본만 보인다', (tester) async {
    await pumpPreview(tester);

    await tester.tap(find.byIcon(Icons.more_horiz));
    await tester.pumpAndSettle();
    await tester.tap(find.text('휴지통'));
    await tester.pumpAndSettle();

    // 제목이 지금 어디를 보고 있는지 알려 준다.
    expect(find.text('휴지통'), findsOneWidget);
    expect(find.text('버린 초안 — 휴지통에서만 보인다'), findsOneWidget);
    expect(find.text('장보기: 우유, 커피 원두, 사과'), findsNothing);

    // 휴지통의 선택 모드는 복원·영구 삭제를 내민다.
    await tester.longPress(find.text('버린 초안 — 휴지통에서만 보인다'));
    await tester.pumpAndSettle();
    expect(find.text('복원'), findsOneWidget);
    expect(find.text('영구 삭제'), findsOneWidget);
  });

  testWidgets('FAB 컴포저로 노트를 만들면 목록 맨 위에 뜬다', (tester) async {
    await pumpPreview(tester);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '새로 적은 노트');
    await tester.pump();
    // 새 노트 타깃의 제출 버튼은 '추가'다 (BRU-158, iOS와 같은 이름).
    await tester.tap(find.text('추가'));
    await tester.pumpAndSettle();

    expect(find.text('새로 적은 노트'), findsOneWidget);
  });
}
