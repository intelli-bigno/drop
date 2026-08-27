import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// 앱 껍데기. 화면·상태는 단계 이슈(BRU-155~159)에서 붙는다 —
/// 여기는 라우터와 테마의 조립만 남긴다 (iOS `DropApp.swift` 대응).
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
      builder: (context, state) => const _PlaceholderHome(),
    ),
  ],
);

class _PlaceholderHome extends StatelessWidget {
  const _PlaceholderHome();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('DROP — Flutter 재구축 (BRU-152)')),
    );
  }
}
