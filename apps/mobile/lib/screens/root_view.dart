/// 인증 상태에 따라 갈라지는 앱의 루트. iOS `Drop/RootView.swift` 대응.
library;

import 'package:drop_core/drop_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../environment/providers.dart';
import 'auth_screen.dart';
import 'home_screen.dart';

/// 루트가 그릴 것. 판정을 위젯 밖의 순수 함수로 둬서 트리를 띄우지 않고 시험한다.
enum RootDestination { loading, auth, home }

RootDestination resolveRootDestination({
  required bool isPreview,
  required AuthState authState,
}) {
  // 프리뷰는 인증을 아예 지나가지 않는다 — 자격증명 없이 화면을 보는 경로다.
  if (isPreview) return RootDestination.home;

  return switch (authState) {
    // 세션 확인 전에 로그인 화면을 띄우면 이미 로그인한 사용자에게
    // 로그인 화면이 한 번 깜빡인다.
    AuthUndetermined() => RootDestination.loading,
    AuthSignedIn() => RootDestination.home,
    AuthWorking() || AuthSignedOut() || AuthFailed() => RootDestination.auth,
  };
}

class RootView extends ConsumerWidget {
  const RootView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final container = ref.watch(dropContainerProvider);
    if (container.isPreview) {
      return const HomeScreen(userId: 'preview');
    }

    final auth = ref.watch(authControllerProvider);
    return switch (resolveRootDestination(
      isPreview: false,
      authState: auth.state,
    )) {
      RootDestination.loading =>
        const Scaffold(body: Center(child: CircularProgressIndicator())),
      RootDestination.home => HomeScreen(
          // 로그인한 사용자가 바뀌면 목록 상태를 처음부터 다시 만든다.
          key: ValueKey(auth.user?.id),
          userId: auth.user?.id,
        ),
      RootDestination.auth => const AuthScreen(),
    };
  }
}
