/// 컨테이너를 위젯 트리로 흘려보내는 Riverpod 배선.
/// iOS `DropContainerEnvironmentKey.swift`(SwiftUI 환경 주입) 대응.
library;

import 'dart:async';

import 'package:drop_core/drop_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_controller.dart';
import '../notes/comments_controller.dart';
import '../notes/notes_controller.dart';
import 'drop_environment_container.dart';

/// 앱 진입점(main)과 테스트가 각자의 컨테이너로 override한다.
/// 기본값이 없는 이유: 잘못된 구성으로 조용히 실행을 이어가지 않기 위해서다.
final dropContainerProvider = Provider<DropEnvironmentContainer>(
  (ref) =>
      throw StateError('dropContainerProvider는 main() 또는 테스트에서 override되어야 한다'),
);

final authControllerProvider = ChangeNotifierProvider<AuthController>((ref) {
  final container = ref.watch(dropContainerProvider);
  final controller = AuthController(
    AuthStore(
      gateway: container.authenticationGateway,
      identityProvider: container.identityProvider,
    ),
  );
  // 앱 시작 시 저장된 세션 확인. 끝나기 전까지는 undetermined라
  // 루트가 스피너를 그린다 — 로그인 화면이 깜빡이지 않는다.
  unawaited(controller.restore());
  return controller;
});

/// 사용자별로 목록 상태를 처음부터 다시 만든다 (iOS `.id(auth.user?.id)` 대응) —
/// 로그인한 사용자가 바뀌었는데 이전 목록이 남아 있으면 남의 노트가 보인다.
final notesControllerProvider = ChangeNotifierProvider.autoDispose
    .family<NotesController, String?>((ref, userId) {
      final container = ref.watch(dropContainerProvider);
      final controller = NotesController(
        NotesStore(repository: container.notesRepository),
      );
      unawaited(controller.load());
      return controller;
    });

/// 댓글 뱃지 숫자. 노트 목록과 별개의 왕복 한 번 — iOS `CommentsStore` 대응.
final commentsControllerProvider = ChangeNotifierProvider.autoDispose
    .family<CommentsController, String?>((ref, userId) {
      final container = ref.watch(dropContainerProvider);
      final controller = CommentsController(
        CommentsStore(repository: container.commentsRepository),
      );
      unawaited(controller.loadCounts());
      return controller;
    });
