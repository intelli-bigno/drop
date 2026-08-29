/// 할일 카드·필터 위젯 테스트 (BRU-184).
///
/// 데스크톱에서 이 기능을 낼 때 단위 테스트·타입 검사가 전부 통과했는데도
/// 필터 버튼에 스타일이 통째로 빠져 있었다(BRU-175, 앱을 띄워서야 발견). 화면에
/// 실제로 그려지는 것을 여기서 못 박는다.
///
/// **자기 픽스처를 들고 온다.** 공유 표본(`PreviewLaunch.sampleNotes`)에 노트를
/// 더했더니 목록이 길어져 `home_screen_test`가 보던 '어제' 섹션 헤더가 화면 밖으로
/// 밀렸다. 표본은 그대로 두고 이 테스트만 자기 노트를 쓴다.
library;

import 'package:drop_core/drop_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app.dart';
import 'package:mobile/environment/drop_environment_container.dart';
import 'package:mobile/environment/providers.dart';

final _now = DateTime.now().toUtc();

Note _note(
  String id, {
  required int displayId,
  required String content,
  NoteType type = NoteType.note,
  DateTime? completedAt,
  required int secondsAgo,
}) =>
    Note(
      id: id,
      displayId: displayId,
      content: content,
      createdAt: _now.subtract(Duration(seconds: secondsAgo)),
      updatedAt: _now,
      source: NoteSource.desktop,
      type: type,
      completedAt: completedAt,
    );

/// 미완료 할일 1 + 완료 할일 1 + 일반 노트 1.
/// 셋이면 체크박스가 할일에만 붙는 것과 완료 표시를 모두 볼 수 있다.
List<Note> _fixture() => [
      _note('t1',
          displayId: 21,
          content: '세금계산서 발행',
          type: NoteType.todo,
          secondsAgo: 600),
      _note('t2',
          displayId: 22,
          content: '회의 자료 정리',
          type: NoteType.todo,
          completedAt: _now.subtract(const Duration(seconds: 300)),
          secondsAgo: 900),
      _note('p1', displayId: 23, content: '그냥 생각 하나', secondsAgo: 1200),
    ];

Future<void> pumpPreview(WidgetTester tester) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [
      dropContainerProvider.overrideWithValue(
        DropEnvironmentContainer.preview(notes: _fixture()),
      ),
    ],
    child: const DropApp(),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('체크박스는 할일에만 붙는다 — 일반 노트에는 없다', (tester) async {
    await pumpPreview(tester);

    // 표본의 할일 둘
    expect(find.text('세금계산서 발행'), findsOneWidget);
    expect(find.text('회의 자료 정리'), findsOneWidget);

    // 미완료 하나 + 완료 하나 = 빈 체크박스 1, 채운 체크박스 1
    expect(find.byIcon(Icons.check_box_outline_blank), findsOneWidget);
    expect(find.byIcon(Icons.check_box), findsOneWidget);
  });

  testWidgets('끝난 할일은 목록에 남고 취소선이 그어진다', (tester) async {
    await pumpPreview(tester);

    final done = tester.widget<Text>(find.text('회의 자료 정리'));
    expect(done.style?.decoration, TextDecoration.lineThrough);

    // 사라지지 않는 것이 핵심 — 방금 끝낸 것이 눈앞에서 없어지면 안 된다
    expect(find.text('회의 자료 정리'), findsOneWidget);
  });

  testWidgets('일반 노트에는 취소선이 없다', (tester) async {
    await pumpPreview(tester);
    final plain = tester.widget<Text>(find.text('그냥 생각 하나'));
    expect(plain.style?.decoration, isNot(TextDecoration.lineThrough));
  });

  testWidgets('체크박스를 누르면 완료가 뒤집힌다', (tester) async {
    await pumpPreview(tester);

    await tester.tap(find.byIcon(Icons.check_box_outline_blank));
    // 카드에 onDoubleTap이 있어 싱글탭 판정이 더블탭 대기만큼 늦는다 —
    // 시간을 흘려 제스처 아레나를 끝낸다 (home_screen_test의 singleTap과 같은 이유).
    await tester.pumpAndSettle(const Duration(milliseconds: 400));

    // 미완료가 하나 줄고 완료가 하나 는다
    expect(find.byIcon(Icons.check_box_outline_blank), findsNothing);
    expect(find.byIcon(Icons.check_box), findsNWidgets(2));
  });

  testWidgets('할일 칩은 남은 개수를 보여 주고, 누르면 필터가 순환한다', (tester) async {
    await pumpPreview(tester);

    // 표본의 할일 2건 중 완료 1건 → 남은 1건
    expect(find.text('할일 1'), findsOneWidget);

    await tester.tap(find.text('할일 1'));
    await tester.pumpAndSettle();

    // 1) 할일 전체 — 끝난 것도 보인다
    expect(find.text('할일 전체'), findsOneWidget);
    expect(find.text('세금계산서 발행'), findsOneWidget);
    expect(find.text('회의 자료 정리'), findsOneWidget);
    expect(find.text('그냥 생각 하나'), findsNothing);

    await tester.tap(find.text('할일 전체'));
    await tester.pumpAndSettle();

    // 2) 남은 할일만
    expect(find.text('남은 할일 1'), findsOneWidget);
    expect(find.text('세금계산서 발행'), findsOneWidget);
    expect(find.text('회의 자료 정리'), findsNothing);

    await tester.tap(find.text('남은 할일 1'));
    await tester.pumpAndSettle();

    // 3) 다시 전체
    expect(find.text('할일 1'), findsOneWidget);
    expect(find.text('그냥 생각 하나'), findsOneWidget);
  });
}
