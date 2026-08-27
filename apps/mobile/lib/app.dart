import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'screens/note_detail_screen.dart';
import 'screens/root_view.dart';

/// 앱 껍데기 — 라우터와 테마의 조립만 (iOS `DropApp.swift` 대응).
/// 인증 게이트는 루트 라우트의 `RootView`가 상태로 가른다.
class DropApp extends StatefulWidget {
  const DropApp({super.key});

  @override
  State<DropApp> createState() => _DropAppState();
}

class _DropAppState extends State<DropApp> {
  // 라우터는 앱 인스턴스마다 하나다 — 전역으로 두면 내비게이션 스택이
  // 테스트(pumpWidget) 사이에 살아남아 다음 화면이 엉뚱한 곳에서 시작한다.
  late final GoRouter _router = createRouter();

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(title: 'DROP', routerConfig: _router);
  }
}

GoRouter createRouter() => GoRouter(
  routes: [
    GoRoute(path: '/', builder: (context, state) => const RootView()),
    // 뷰어 (BRU-77). 지금은 읽기 전용 플레이스홀더 — BRU-157이 화면만 갈아끼운다.
    GoRoute(
      path: '/note/:id',
      builder: (context, state) => NoteDetailScreen(
        noteId: state.pathParameters['id']!,
        userId: state.extra as String?,
      ),
    ),
  ],
);
