import 'package:drop_core/drop_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/screens/root_view.dart';

void main() {
  group('resolveRootDestination', () {
    test('프리뷰 모드는 인증 상태와 무관하게 홈으로 간다', () {
      for (final state in const <AuthState>[
        AuthUndetermined(),
        AuthSignedOut(),
        AuthFailed('x'),
      ]) {
        expect(
          resolveRootDestination(isPreview: true, authState: state),
          RootDestination.home,
        );
      }
    });

    test('세션 확인 전에는 로그인 화면 대신 로딩을 그린다', () {
      expect(
        resolveRootDestination(
            isPreview: false, authState: const AuthUndetermined()),
        RootDestination.loading,
      );
    });

    test('로그인되면 홈, 아니면 로그인 화면', () {
      expect(
        resolveRootDestination(
          isPreview: false,
          authState: const AuthSignedIn(DropUser(id: 'u1', email: null)),
        ),
        RootDestination.home,
      );
      for (final state in const <AuthState>[
        AuthSignedOut(),
        AuthWorking(),
        AuthFailed('boom'),
      ]) {
        expect(
          resolveRootDestination(isPreview: false, authState: state),
          RootDestination.auth,
        );
      }
    });
  });
}
