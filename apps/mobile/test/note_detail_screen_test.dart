/// 노트 뷰어·댓글 시트·미디어 뷰어 위젯 테스트 (BRU-157).
/// 프리뷰 컨테이너의 인메모리 표본으로 iOS `NoteDetailView.swift` ·
/// `CommentsSheet.swift` · `MediaViewer.swift`의 계약을 검증한다.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app.dart';
import 'package:mobile/environment/drop_environment_container.dart';
import 'package:mobile/environment/providers.dart';
import 'package:mobile/screens/media_viewer_screen.dart';
import 'package:mobile/screens/note_detail_screen.dart';
import 'package:mobile/widgets/attachment_thumbnail.dart';

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

/// 홈 카드의 GestureDetector에 onDoubleTap이 있어 싱글탭 판정이 더블탭
/// 대기만큼 늦어진다 — 탭 뒤에 시간을 흘려 판정을 끝낸다.
Future<void> singleTap(WidgetTester tester, Finder finder) async {
  await tester.tap(finder);
  await tester.pumpAndSettle(const Duration(milliseconds: 400));
}

/// 목록에서 노트를 눌러 뷰어를 연다. 표본이 늘면 그 행이 화면 밖으로 밀리므로
/// 먼저 보이는 데까지 굴린다 — 안 보이는 위젯은 눌러도 아무 일도 안 일어난다.
Future<void> openViewer(WidgetTester tester, String cardText) async {
  final card = find.textContaining(cardText).first;
  await tester.scrollUntilVisible(
    card,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
  await singleTap(tester, card);
  expect(find.byType(NoteDetailScreen), findsOneWidget);
}

void main() {
  testWidgets('뷰어는 마크다운을 위젯으로 그린다 — 기호는 보이지 않는다', (tester) async {
    await pumpPreview(tester);
    await tester.scrollUntilVisible(
      find.textContaining('이번 주 정리'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await openViewer(tester, '이번 주 정리');

    // 제목은 기호 없이 텍스트만.
    expect(find.text('이번 주 정리'), findsOneWidget);
    expect(find.textContaining('# 이번 주 정리'), findsNothing);
    // 체크박스는 아이콘으로 — 완료·미완료가 갈린다.
    expect(find.byIcon(Icons.check_box), findsOneWidget);
    expect(find.byIcon(Icons.check_box_outline_blank), findsNWidgets(2));
    expect(find.text('파서를 DropCore에 두기'), findsOneWidget);
    // 코드 블록은 원문 그대로.
    expect(
      find.text('let document = MarkdownParser().parse(note.content)'),
      findsOneWidget,
    );
    // 인용·링크 텍스트.
    expect(find.text('저장 형식은 평문 마크다운 그대로다.'), findsOneWidget);
    expect(find.text('이슈 보기'), findsOneWidget);
  });

  testWidgets('활성 노트의 상태 메뉴: 보관을 누르면 뷰어가 닫히고 목록에서 사라진다', (tester) async {
    await pumpPreview(tester);
    await openViewer(tester, '장보기: 우유, 커피 원두, 사과');

    // 동작은 ⋯ 안이 아니라 앱바에 하나씩 서 있다 (BRU-207).
    expect(find.byTooltip('보관'), findsOneWidget);
    expect(find.byTooltip('휴지통으로'), findsOneWidget);
    // 활성 노트에 복원·영구 삭제는 없다.
    expect(find.byTooltip('복원'), findsNothing);
    expect(find.byTooltip('영구 삭제'), findsNothing);

    await tester.tap(find.byTooltip('보관'));
    await tester.pumpAndSettle();

    // 상태를 바꿨으면 뷰어를 닫는다 (iOS와 같은 규칙).
    expect(find.byType(NoteDetailScreen), findsNothing);
    expect(find.textContaining('장보기: 우유'), findsNothing);
  });

  testWidgets('휴지통 노트의 뷰어: 편집이 없고, 영구 삭제가 목록에서 지운다', (tester) async {
    await pumpPreview(tester);
    // 휴지통 뷰로 이동. 홈의 보기 전환은 ⋯ 시트 안의 세그먼트다.
    await tester.tap(find.byIcon(Icons.more_horiz));
    await tester.pumpAndSettle();
    await tester.tap(find.text('휴지통'));
    await tester.pumpAndSettle();
    await openViewer(tester, '버린 초안');

    // 휴지통 노트는 본문을 고칠 수 없다 — 편집 진입 자체가 없다.
    expect(find.byTooltip('편집'), findsNothing);

    expect(find.byTooltip('복원'), findsOneWidget);
    await tester.tap(find.byTooltip('영구 삭제'));
    await tester.pumpAndSettle();
    // 되돌릴 수 없는 일이라 확인 시트가 한 번 선다 (BRU-207, MASTER §규칙 4).
    expect(find.text('이 노트를 영구 삭제할까요?'), findsOneWidget);
    await tester.tap(find.text('삭제'));
    await tester.pumpAndSettle();

    expect(find.byType(NoteDetailScreen), findsNothing);
    expect(find.text('휴지통이 비어 있습니다'), findsOneWidget);
  });

  testWidgets('편집 버튼은 컴포저 시트를 연다 — 뷰어의 유일한 쓰기 진입 (BRU-77)', (tester) async {
    await pumpPreview(tester);
    await openViewer(tester, '장보기: 우유, 커피 원두, 사과');

    await tester.tap(find.byTooltip('편집'));
    await tester.pumpAndSettle();

    // 컴포저 스텁이 뜬다 — 기존 노트 대상 편집은 BRU-158이 갈아끼운다.
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.text('저장'), findsOneWidget);
  });

  testWidgets('댓글 시트: 표본 목록이 뜨고, 새 댓글을 달면 개수까지 움직인다', (tester) async {
    await pumpPreview(tester);
    await openViewer(tester, 'iOS 네이티브 전환 M3');

    // 부속 묶음의 '댓글' 줄 — 이름표와 값이 갈라져 값만 센다 (BRU-207).
    expect(find.text('3개'), findsOneWidget);
    await tester.tap(find.text('3개'));
    await tester.pumpAndSettle();

    // 표본 댓글이 오래된 순으로 보인다 — 작성자 표기는 없다 (개인 앱).
    expect(find.text('M3까지는 왔는데 위젯이 아직 남았다.'), findsOneWidget);
    expect(find.text('위젯은 BRU-35에서 따로 본다.'), findsOneWidget);
    expect(find.text('확인.'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '넷째 댓글');
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('댓글 보내기'));
    await tester.pumpAndSettle();

    expect(find.text('넷째 댓글'), findsOneWidget);
    // 입력창은 비워졌다.
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      '',
    );

    // 시트를 닫으면 뷰어의 댓글 버튼 개수도 새 값이다.
    await tester.tapAt(const Offset(400, 40));
    await tester.pumpAndSettle();
    expect(find.text('4개'), findsOneWidget);
  });

  testWidgets('댓글 스와이프 삭제 — 휴지통 없이 바로 지워진다', (tester) async {
    await pumpPreview(tester);
    await openViewer(tester, 'iOS 네이티브 전환 M3');
    await tester.tap(find.text('3개'));
    await tester.pumpAndSettle();

    await tester.drag(find.text('확인.'), const Offset(-500, 0));
    await tester.pumpAndSettle();
    // 하드 삭제라 스와이프 끝에서 한 번 묻는다 (BRU-207).
    expect(find.text('이 댓글을 지울까요?'), findsOneWidget);
    await tester.tap(find.text('지우기'));
    await tester.pumpAndSettle();

    expect(find.text('확인.'), findsNothing);
    expect(find.text('M3까지는 왔는데 위젯이 아직 남았다.'), findsOneWidget);
  });

  testWidgets('첨부 썸네일 → 미디어 뷰어: 스와이프 페이지, 더블탭 닫기', (tester) async {
    await pumpPreview(tester);
    await openViewer(tester, '제주 사진 몇 장');

    // 이미지 3장 — 프리뷰에는 스토리지가 없어 아이콘 자리표시로 남는다.
    expect(find.byType(AttachmentThumbnail), findsNWidgets(3));

    await tester.tap(find.byType(AttachmentThumbnail).first);
    await tester.pumpAndSettle();
    expect(find.byType(MediaViewerScreen), findsOneWidget);
    expect(find.text('img1.png'), findsOneWidget);
    // 서명 URL 실패는 자리표시로 — 앱이 죽지 않는다.
    expect(find.text('불러오지 못했습니다'), findsOneWidget);

    // 스와이프로 다음 첨부.
    await tester.drag(find.byType(PageView), const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(find.text('img2.png'), findsOneWidget);

    // 더블탭이 닫기다 (BRU-157 완료 조건).
    final center = tester.getCenter(find.byType(PageView));
    await tester.tapAt(center);
    await tester.pump(const Duration(milliseconds: 80));
    await tester.tapAt(center);
    await tester.pumpAndSettle();
    expect(find.byType(MediaViewerScreen), findsNothing);
    expect(find.byType(NoteDetailScreen), findsOneWidget);
  });
}
