import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drop_mobile/presentation/widgets/action_buttons.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(
        home: Scaffold(floatingActionButton: child),
      );

  ActionButtons buildButtons({
    bool isRecording = false,
    VoidCallback? onAdd,
    VoidCallback? onRecord,
    VoidCallback? onCamera,
    VoidCallback? onGallery,
    ValueChanged<bool>? onExpandedChanged,
  }) {
    return ActionButtons(
      isRecording: isRecording,
      onAddPressed: onAdd ?? () {},
      onRecordPressed: onRecord ?? () {},
      onCameraPressed: onCamera ?? () {},
      onGalleryPressed: onGallery ?? () {},
      onExpandedChanged: onExpandedChanged,
    );
  }

  testWidgets('shouldShowOnlyTriggerFabWhenCollapsed', (tester) async {
    await tester.pumpWidget(wrap(buildButtons()));

    expect(find.byIcon(Icons.add), findsOneWidget);
    expect(find.byIcon(Icons.mic), findsNothing);
    expect(find.byIcon(Icons.camera_alt), findsNothing);
    expect(find.byIcon(Icons.photo_library), findsNothing);
  });

  testWidgets('shouldRevealLabeledActionsWhenTriggerTapped', (tester) async {
    await tester.pumpWidget(wrap(buildButtons()));

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.mic), findsOneWidget);
    expect(find.byIcon(Icons.camera_alt), findsOneWidget);
    expect(find.byIcon(Icons.photo_library), findsOneWidget);
    expect(find.text('녹음'), findsOneWidget);
    expect(find.text('카메라'), findsOneWidget);
    expect(find.text('갤러리'), findsOneWidget);
    expect(find.byIcon(Icons.close), findsOneWidget);
  });

  testWidgets('shouldCollapseWhenTriggerTappedTwice', (tester) async {
    await tester.pumpWidget(wrap(buildButtons()));

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.mic), findsNothing);
    expect(find.byIcon(Icons.add), findsOneWidget);
  });

  testWidgets('shouldInvokeCallbackAndCollapseWhenActionTapped', (tester) async {
    var recordCalls = 0;
    await tester.pumpWidget(wrap(buildButtons(onRecord: () => recordCalls++)));

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.mic));
    await tester.pumpAndSettle();

    expect(recordCalls, 1);
    expect(find.byIcon(Icons.mic), findsNothing);
  });

  testWidgets('shouldOpenComposerWhenTriggerTappedWhileRecording', (tester) async {
    var addCalls = 0;
    await tester.pumpWidget(
      wrap(buildButtons(isRecording: true, onAdd: () => addCalls++)),
    );

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    expect(addCalls, 1);
    expect(find.byIcon(Icons.mic), findsNothing);
  });

  testWidgets('shouldNotifyExpansionChanges', (tester) async {
    final changes = <bool>[];
    await tester.pumpWidget(
      wrap(buildButtons(onExpandedChanged: changes.add)),
    );

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(changes, [true, false]);
  });

  testWidgets('shouldSettleClosedWhenReversedMidFlight', (tester) async {
    await tester.pumpWidget(wrap(buildButtons()));

    await tester.tap(find.byIcon(Icons.add));
    // Interrupt while the dial is still opening.
    await tester.pump(const Duration(milliseconds: 40));
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.mic), findsNothing);
    expect(find.text('녹음'), findsNothing);
    expect(find.byIcon(Icons.add), findsOneWidget);
  });

  testWidgets('shouldCollapseWhenHostRequestsIt', (tester) async {
    final key = GlobalKey<ActionButtonsState>();
    await tester.pumpWidget(wrap(ActionButtons(
      key: key,
      isRecording: false,
      onAddPressed: () {},
      onRecordPressed: () {},
      onCameraPressed: () {},
      onGalleryPressed: () {},
    )));

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    key.currentState!.collapse();
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.mic), findsNothing);
    expect(find.byIcon(Icons.add), findsOneWidget);
  });

  testWidgets('shouldCollapseWhenRecordingStarts', (tester) async {
    await tester.pumpWidget(wrap(buildButtons()));
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    await tester.pumpWidget(wrap(buildButtons(isRecording: true)));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.mic), findsNothing);
    expect(find.byIcon(Icons.close), findsNothing);
    expect(find.byIcon(Icons.add), findsOneWidget);
  });
}
