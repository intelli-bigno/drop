/// 위젯 스냅샷 발행 배선 (BRU-160). 스냅샷을 만드는 규칙은 drop_core
/// `widget_snapshot_test.dart`가 덮는다 — 여기서는 "홈이 목록을 들면 App Group에
/// 요약이 적히고 위젯 리로드가 불린다"는 배선만 본다 (iOS
/// `WidgetSnapshotPublisher` 대응).
library;

import 'dart:io';

import 'package:drop_core/drop_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app.dart';
import 'package:mobile/environment/drop_environment_container.dart';
import 'package:mobile/environment/providers.dart';
import 'package:mobile/native/native_shell.dart';

class FakeNativeShell extends NativeShell {
  final String? containerPath;
  int reloadCount = 0;

  FakeNativeShell(this.containerPath);

  @override
  Future<String?> appGroupContainerPath() async => containerPath;

  @override
  Future<void> reloadWidgets() async => reloadCount += 1;
}

void main() {
  late Directory container;

  setUp(() {
    container = Directory.systemTemp.createTempSync('app-group');
  });

  tearDown(() {
    if (container.existsSync()) container.deleteSync(recursive: true);
  });

  testWidgets('홈이 목록을 들면 App Group에 스냅샷이 적히고 위젯 리로드가 불린다',
      (tester) async {
    final shell = FakeNativeShell(container.path);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        dropContainerProvider
            .overrideWithValue(DropEnvironmentContainer.preview()),
        nativeShellProvider.overrideWithValue(shell),
      ],
      child: const DropApp(),
    ));
    await tester.pumpAndSettle();

    final snapshot = WidgetSnapshotStore(container).read();
    expect(snapshot.isEmpty, isFalse);
    expect(snapshot.notes.length, WidgetSnapshot.maximumNoteCount);
    // 적힌 줄들은 표본 목록에서 규칙대로 만든 것과 같아야 한다.
    // (표본의 createdAt은 "지금" 기준 상대값이라 시각까지는 비교하지 않는다.)
    final sample =
        await DropEnvironmentContainer.preview().notesRepository.loadNotes();
    final expected = WidgetSnapshot.fromNotes(sample).notes;
    expect(
      snapshot.notes.map((n) => '${n.id}|${n.excerpt}'),
      expected.map((n) => '${n.id}|${n.excerpt}'),
    );
    expect(shell.reloadCount, greaterThan(0));
  });
}
