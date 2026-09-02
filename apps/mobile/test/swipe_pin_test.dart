/// 목록 행 스와이프로 고정을 걸고 푸는 경로 (BRU-207).
///
/// 그 전까지 Flutter 앱에는 고정 진입점이 하나도 없었다 — `drop_core`는 갖췄는데
/// 화면이 부르지 않아, 데스크톱에서 꽂은 노트를 모바일에서 풀 수 없었다.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/widgets/drop_swipe_row.dart';
import 'package:mobile/widgets/note_group.dart';

import 'home_screen_test.dart' show pumpPreview;

/// 스와이프로 드러난 동작만 고른다 — "고정"은 섹션 머리글에도 있는 글자다.
Finder swipeAction(String label) => find.descendant(
  of: find.byType(DropSwipeRow),
  matching: find.text(label),
);

/// 이 노트가 앉아 있는 묶음이 고정 묶음인가.
bool inPinnedGroup(WidgetTester tester, String noteText) => tester
    .widget<NoteGroup>(
      find
          .ancestor(
            of: find.text(noteText),
            matching: find.byType(NoteGroup),
          )
          .first,
    )
    .isPinned;

Future<void> swipeOpen(WidgetTester tester, String noteText) async {
  await tester.drag(find.text(noteText), const Offset(-160, 0));
  await tester.pumpAndSettle();
}

void main() {
  const plain = '전세 계약서 특약 확인하기';
  const pinned = 'iOS 네이티브 전환 M3 — 홈 화면까지 올라왔다.';

  testWidgets('행을 왼쪽으로 밀면 「고정」이 나오고, 누르면 고정 묶음으로 올라간다', (tester) async {
    await pumpPreview(tester);
    expect(inPinnedGroup(tester, plain), isFalse);

    await swipeOpen(tester, plain);
    expect(swipeAction('고정'), findsOneWidget);

    await tester.tap(swipeAction('고정'));
    await tester.pumpAndSettle();

    expect(inPinnedGroup(tester, plain), isTrue);
  });

  testWidgets('이미 고정된 행에는 「고정 해제」가 나오고, 누르면 묶음에서 빠진다', (tester) async {
    await pumpPreview(tester);
    expect(inPinnedGroup(tester, pinned), isTrue);

    await swipeOpen(tester, pinned);
    expect(swipeAction('고정 해제'), findsOneWidget);

    await tester.tap(swipeAction('고정 해제'));
    await tester.pumpAndSettle();

    expect(inPinnedGroup(tester, pinned), isFalse);
  });

  testWidgets('밀다 만 줄은 손을 떼면 닫힌다 — 절반을 못 넘겼다', (tester) async {
    await pumpPreview(tester);
    await tester.drag(find.text(plain), const Offset(-20, 0));
    await tester.pumpAndSettle();

    expect(swipeAction('고정'), findsNothing);
  });

  testWidgets('한 번에 한 줄만 열린다', (tester) async {
    await pumpPreview(tester);
    await swipeOpen(tester, plain);
    expect(swipeAction('고정'), findsOneWidget);

    await swipeOpen(tester, pinned);
    // 앞서 연 줄은 닫혔고, 지금 열린 줄의 동작만 남는다.
    expect(swipeAction('고정'), findsNothing);
    expect(swipeAction('고정 해제'), findsOneWidget);
  });

  testWidgets('선택 모드에서는 스와이프가 꺼진다', (tester) async {
    await pumpPreview(tester);
    await tester.longPress(find.text(plain));
    await tester.pumpAndSettle();
    expect(find.text('1개 선택됨'), findsOneWidget);

    await swipeOpen(tester, plain);
    expect(swipeAction('고정'), findsNothing);
  });

  testWidgets('휴지통에서는 고정이 없다 — 지울 노트를 상단에 꽂지 않는다', (tester) async {
    await pumpPreview(tester);
    await tester.tap(find.byIcon(Icons.more_horiz));
    await tester.pumpAndSettle();
    await tester.tap(find.text('휴지통'));
    await tester.pumpAndSettle();

    await swipeOpen(tester, '버린 초안 — 휴지통에서만 보인다');
    expect(swipeAction('고정'), findsNothing);
  });
}
