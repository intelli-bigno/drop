import 'package:drop_core/drop_core.dart';
import 'package:test/test.dart';

/// DropCore `AuthStoreTests.swift` 포팅.
/// 실제 Google / Supabase 없이 게이트웨이를 갈아끼워 상태 전이를 검증한다.
void main() {
  (AuthStore, FakeAuthenticationGateway, FakeGoogleIdentityProvider) makeStore({
    FakeAuthenticationGateway? gateway,
    FakeGoogleIdentityProvider? identity,
  }) {
    final g = gateway ?? FakeAuthenticationGateway();
    final i = identity ?? FakeGoogleIdentityProvider();
    return (AuthStore(gateway: g, identityProvider: i), g, i);
  }

  group('인증 상태 전이', () {
    test('시작 상태는 판단 보류다', () {
      final (store, _, _) = makeStore();
      expect(store.state, const AuthUndetermined());
    });

    test('기존 세션이 있으면 복원한다', () async {
      final gateway = FakeAuthenticationGateway()
        ..currentUser =
            const DropUser(id: 'u1', email: 'bruce@intellieffect.com');
      final (store, _, _) = makeStore(gateway: gateway);

      await store.restore();

      expect(
        store.state,
        const AuthSignedIn(DropUser(id: 'u1', email: 'bruce@intellieffect.com')),
      );
    });

    test('세션이 없으면 로그아웃 상태다', () async {
      final (store, _, _) = makeStore();

      await store.restore();

      expect(store.state, const AuthSignedOut());
    });

    test('로그인에 성공하면 사용자를 노출한다', () async {
      final identity = FakeGoogleIdentityProvider()
        ..identity = const GoogleIdentity(idToken: 'id', accessToken: 'access');
      final gateway = FakeAuthenticationGateway()
        ..signInError = null
        ..signInUser = const DropUser(id: 'u2', email: 'a@b.c');
      final (store, _, _) = makeStore(gateway: gateway, identity: identity);

      await store.signInWithGoogle();

      expect(store.state, const AuthSignedIn(DropUser(id: 'u2', email: 'a@b.c')));
      expect(gateway.receivedIdToken, 'id');
      expect(gateway.receivedAccessToken, 'access');
    });

    /// 사용자가 로그인 창을 닫은 것은 오류가 아니다.
    test('사용자가 취소하면 오류가 아니라 로그아웃으로 되돌린다', () async {
      final identity = FakeGoogleIdentityProvider()..identity = null;
      final (store, _, _) = makeStore(identity: identity);

      await store.signInWithGoogle();

      expect(store.state, const AuthSignedOut());
    });

    test('로그인이 실패하면 메시지를 남긴다', () async {
      final identity = FakeGoogleIdentityProvider()
        ..identity = const GoogleIdentity(idToken: 'id', accessToken: null);
      final gateway = FakeAuthenticationGateway()..signInError = 'boom';
      final (store, _, _) = makeStore(gateway: gateway, identity: identity);

      await store.signInWithGoogle();

      expect(store.state, isA<AuthFailed>());
    });

    test('로그아웃하면 Google 세션까지 함께 끊는다', () async {
      final identity = FakeGoogleIdentityProvider()
        ..identity = const GoogleIdentity(idToken: 'id', accessToken: null);
      final gateway = FakeAuthenticationGateway()
        ..signInError = null
        ..signInUser = const DropUser(id: 'u3', email: null);
      final (store, _, _) = makeStore(gateway: gateway, identity: identity);
      await store.signInWithGoogle();

      await store.signOut();

      expect(store.state, const AuthSignedOut());
      expect(gateway.signOutCallCount, 1);
      expect(identity.signOutCallCount, 1);
    });

    /// 실패한 뒤 다시 시도하면 이전 오류 메시지가 남아 있으면 안 된다.
    test('재시도하면 이전 오류 표시가 사라진다', () async {
      final identity = FakeGoogleIdentityProvider()
        ..identity = const GoogleIdentity(idToken: 'id', accessToken: null);
      final gateway = FakeAuthenticationGateway()..signInError = 'boom';
      final (store, _, _) = makeStore(gateway: gateway, identity: identity);
      await store.signInWithGoogle();

      gateway
        ..signInError = null
        ..signInUser = const DropUser(id: 'u4', email: null);
      await store.signInWithGoogle();

      expect(store.state, const AuthSignedIn(DropUser(id: 'u4', email: null)));
    });
  });
}

class FakeAuthenticationGateway implements AuthenticationGateway {
  @override
  DropUser? currentUser;

  DropUser? signInUser;
  String? signInError = 'boom';
  String? receivedIdToken;
  String? receivedAccessToken;
  int signOutCallCount = 0;

  @override
  Future<DropUser> signIn({required String idToken, String? accessToken}) async {
    receivedIdToken = idToken;
    receivedAccessToken = accessToken;
    final error = signInError;
    if (error != null) throw StateError(error);
    return signInUser!;
  }

  @override
  Future<void> signOut() async {
    signOutCallCount += 1;
    currentUser = null;
  }
}

class FakeGoogleIdentityProvider implements GoogleIdentityProvider {
  GoogleIdentity? identity;
  int signOutCallCount = 0;

  @override
  Future<GoogleIdentity?> signIn() async => identity;

  @override
  void signOut() {
    signOutCallCount += 1;
  }
}
