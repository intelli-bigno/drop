import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'screens/root_view.dart';

/// 앱 껍데기 — 라우터와 테마의 조립만 (iOS `DropApp.swift` 대응).
/// 인증 게이트는 루트 라우트의 `RootView`가 상태로 가른다.
class DropApp extends StatelessWidget {
  const DropApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'DROP',
      routerConfig: _router,
    );
  }
}

final _router = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const RootView(),
    ),
  ],
);
