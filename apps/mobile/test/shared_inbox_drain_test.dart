/// 공유 수신함 비우기 배선 (BRU-160). 수신함 파싱 규칙 자체는 drop_core
/// `shared_inbox_test.dart`가 덮는다 — 여기서는 "홈이 켜지면 항목이 노트가
/// 되고 수신함이 빈다"는 배선만 본다 (iOS `HomeView.drainSharedInbox` 대응).
library;

import 'dart:io';

import 'package:drop_core/drop_core.dart';
import 'package:flutter/material.dart';
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

  Widget previewApp(NativeShell shell) => ProviderScope(
        overrides: [
          dropContainerProvider
              .overrideWithValue(DropEnvironmentContainer.preview()),
          nativeShellProvider.overrideWithValue(shell),
        ],
        child: const DropApp(),
      );

  testWidgets('홈이 켜지면 공유 수신함 항목이 노트가 되고 수신함이 빈다', (tester) async {
    final inbox = SharedInbox(Directory('${container.path}/inbox'));
    inbox.enqueue(SharedItem(text: '공유로 들어온 링크'));

    await tester.pumpWidget(previewApp(FakeNativeShell(container.path)));
    await tester.pumpAndSettle();

    expect(find.text('공유로 들어온 링크'), findsOneWidget);
    expect(inbox.drain(), isEmpty);
  });

  testWidgets('App Group이 없으면(안드로이드·테스트) 아무 일도 일어나지 않는다', (tester) async {
    await tester.pumpWidget(previewApp(FakeNativeShell(null)));
    await tester.pumpAndSettle();

    // 프리뷰 표본 목록이 그대로 뜬다 — 실패나 배너가 없다.
    expect(find.text('장보기: 우유, 커피 원두, 사과'), findsOneWidget);
  });
}
