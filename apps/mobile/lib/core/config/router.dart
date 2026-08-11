import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:drop_mobile/presentation/screens/home_screen.dart';
import 'package:drop_mobile/presentation/screens/auth_screen.dart';
import 'package:drop_mobile/presentation/providers/auth_provider.dart';

part 'router.g.dart';

@riverpod
GoRouter router(Ref ref) {
  final isAuth = ref.watch(isAuthenticatedProvider);

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final isAuthRoute = state.matchedLocation == '/auth';

      // Not authenticated and not on auth page -> go to auth
      if (!isAuth && !isAuthRoute) {
        return '/auth';
      }

      // Authenticated and on auth page -> go to home
      if (isAuth && isAuthRoute) {
        return '/';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/auth',
        name: 'auth',
        builder: (context, state) => const AuthScreen(),
      ),
      GoRoute(
        path: '/',
        name: 'home',
        builder: (context, state) => const HomeScreen(),
      ),
    ],
  );
}
