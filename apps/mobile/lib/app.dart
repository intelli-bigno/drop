import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:drop_core/drop_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'links/deep_link_router.dart';
import 'screens/note_detail_screen.dart';
import 'screens/root_view.dart';
import 'screens/tags_screen.dart';
import 'theme/drop_scroll_behavior.dart';
import 'theme/drop_theme.dart';
import 'theme/theme_mode_controller.dart';

/// 앱 껍데기 — 라우터와 테마의 조립만 (iOS `DropApp.swift` 대응).
/// 인증 게이트는 루트 라우트의 `RootView`가 상태로 가른다.
class DropApp extends ConsumerStatefulWidget {
  /// 테스트가 실제 플랫폼 채널 대신 밀어 넣는 링크 스트림.
  /// null이면 `app_links`가 실제 딥링크(초기 링크 포함)를 흘려보낸다.
  final Stream<Uri>? linkStream;

  const DropApp({super.key, this.linkStream});

  @override
  ConsumerState<DropApp> createState() => _DropAppState();
}

class _DropAppState extends ConsumerState<DropApp> {
  // 라우터는 앱 인스턴스마다 하나다 — 전역으로 두면 내비게이션 스택이
  // 테스트(pumpWidget) 사이에 살아남아 다음 화면이 엉뚱한 곳에서 시작한다.
  late final GoRouter _router = createRouter();

  StreamSubscription<Uri>? _links;

  @override
  void initState() {
    super.initState();
    // 위젯 테스트에는 플랫폼 채널이 없다 — 구독 실패는 조용히 무시한다.
    // 딥링크가 안 들어올 뿐 앱의 나머지는 그대로 돌아간다.
    try {
      final stream = widget.linkStream ?? AppLinks().uriLinkStream;
      _links = stream.listen(_handleUri, onError: (Object _) {});
    } catch (_) {}
  }

  @override
  void dispose() {
    _links?.cancel();
    _router.dispose();
    super.dispose();
  }

  /// 우리가 아는 링크면 화면 이동으로 넘긴다. 아니면 건드리지 않는다 —
  /// Google 로그인 콜백이 같은 경로로 들어온다(그쪽은 SDK가 집어 간다).
  void _handleUri(Uri uri) {
    final link = DropLink.parse(uri);
    if (link == null) return;
    // 즉시 화면을 옮기지 않고 보관만 한다 — 콜드 스타트에서는 링크가
    // 화면보다 먼저 도착한다. 소비는 홈(HomeScreen)이 한다.
    ref.read(deepLinkRouterProvider).handle(link);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'DROP',
      debugShowCheckedModeBanner: false,
      scrollBehavior: const DropScrollBehavior(),
      theme: DropTheme.light,
      darkTheme: DropTheme.dark,
      themeMode: ref.watch(themeModeProvider),
      // 테마 전환은 **즉시**다. 머티리얼 기본값(200ms)은 그 사이 매 프레임마다
      // 테마 한 벌 전체(색·하위 테마·텍스트 스타일)를 보간하는데, 그 비용이
      // 전환을 부드럽게 만들기는커녕 화면을 멈춰 세운다 (BRU-207 실측).
      themeAnimationDuration: Duration.zero,
      routerConfig: _router,
    );
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
    GoRoute(
      path: '/tags',
      // 홈과 같은 목록 상태를 보도록 사용자 ID를 쿼리로 받는다:
      // `/tags?user=<id>` (프리뷰는 `preview`).
      builder: (context, state) =>
          TagsScreen(userId: state.uri.queryParameters['user']),
    ),
  ],
);
