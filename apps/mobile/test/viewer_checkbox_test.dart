/// 뷰어에서 본문 체크박스를 눌러 끄고 켜는 계약 (BRU-207).
///
/// 뷰어는 본문을 못 건드린다는 규칙(BRU-77)의 **유일한 예외**다. 열람만으로는
/// 여전히 아무것도 저장되지 않고, 손가락으로 체크박스를 눌렀을 때만 그 한 줄이
/// 바뀐다 — 그 경계가 지켜지는지 여기서 지킨다.
library;

import 'package:drop_core/drop_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app.dart';
import 'package:mobile/environment/drop_environment_container.dart';
import 'package:mobile/environment/providers.dart';

Note noteWith(String content) {
  final now = DateTime.now().toUtc();
  return Note(
    id: 'n1',
    displayId: 1,
    content: content,
    createdAt: now,
    updatedAt: now,
    source: NoteSource.mobile,
  );
}

/// 목록에서 그 노트를 열어 뷰어까지 간다. 저장 결과는 화면으로 확인한다 —
/// 저장이 됐는지는 목록이 다시 불러온 본문이 화면에 그려지는 것으로 드러난다.
Future<void> pumpViewer(WidgetTester tester, String content) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        dropContainerProvider.overrideWithValue(
          DropEnvironmentContainer.preview(notes: [noteWith(content)]),
        ),
      ],
      child: const DropApp(),
    ),
  );
  await tester.pumpAndSettle();

  await tester.tap(find.textContaining('첫째'));
  await tester.pumpAndSettle(const Duration(milliseconds: 400));
}

void main() {
  testWidgets('체크박스를 누르면 그 줄만 바뀐다', (tester) async {
    await pumpViewer(tester, '- [ ] 첫째\n- [ ] 둘째');
    expect(find.byIcon(Icons.check_box_outline_blank), findsNWidgets(2));

    await tester.tap(find.byIcon(Icons.check_box_outline_blank).first);
    await tester.pumpAndSettle();

    // 누른 줄만 켜졌다 — 둘째는 그대로다.
    expect(find.byIcon(Icons.check_box), findsOneWidget);
    expect(find.byIcon(Icons.check_box_outline_blank), findsOneWidget);
    expect(find.text('1 / 2'), findsOneWidget);
  });

  testWidgets('켠 것을 다시 누르면 꺼진다', (tester) async {
    await pumpViewer(tester, '- [x] 첫째');
    expect(find.text('1 / 1'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.check_box));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.check_box_outline_blank), findsOneWidget);
    expect(find.text('0 / 1'), findsOneWidget);
  });

  testWidgets('뷰어를 열기만 해서는 본문이 바뀌지 않는다 (BRU-66)', (tester) async {
    await pumpViewer(tester, '- [ ] 첫째\n- [x] 둘째');

    expect(find.text('1 / 2'), findsOneWidget);
    expect(find.byIcon(Icons.check_box), findsOneWidget);
    expect(find.byIcon(Icons.check_box_outline_blank), findsOneWidget);
  });

  testWidgets('체크박스 진행이 머리에 뜬다', (tester) async {
    await pumpViewer(tester, '- [x] 첫째\n- [ ] 둘째\n- [ ] 셋째');

    expect(find.text('1 / 3'), findsOneWidget);
    expect(find.text('할일'), findsWidgets);
  });
}
