/// 인증 상태 전이. DropCore `AuthStore.swift` 대응.
///
/// Google 로그인 창을 띄우는 SDK(google_sign_in)와 Supabase 세션은 Flutter 쪽
/// 몫이다 — drop_core는 결과 토큰과 상태 전이만 다룬다.
library;

class DropUser {
  final String id;
  final String? email;

  const DropUser({required this.id, required this.email});

  @override
  bool operator ==(Object other) =>
      other is DropUser && other.id == id && other.email == email;

  @override
  int get hashCode => Object.hash(id, email);

  @override
  String toString() => 'DropUser($id, $email)';
}

/// Google에서 받아온 자격증명. 화면이 필요한 SDK 호출은 앱이 맡고,
/// drop_core는 결과 토큰만 받는다.
class GoogleIdentity {
  final String idToken;
  final String? accessToken;

  const GoogleIdentity({required this.idToken, required this.accessToken});

  @override
  bool operator ==(Object other) =>
      other is GoogleIdentity &&
      other.idToken == idToken &&
      other.accessToken == accessToken;

  @override
  int get hashCode => Object.hash(idToken, accessToken);
}

/// Google 로그인 창을 띄우는 쪽. `null` 반환은 **사용자 취소**를 뜻한다.
abstract interface class GoogleIdentityProvider {
  Future<GoogleIdentity?> signIn();
  void signOut();
}

/// Supabase 인증에 대한 얇은 경계. 테스트에서 통째로 갈아끼운다.
abstract interface class AuthenticationGateway {
  DropUser? get currentUser;
  Future<DropUser> signIn({required String idToken, String? accessToken});
  Future<void> signOut();
}

sealed class AuthState {
  const AuthState();
}

/// 아직 세션을 확인하기 전. 이 상태에서 로그인 화면을 띄우면
/// 이미 로그인된 사용자에게 로그인 화면이 깜빡인다.
class AuthUndetermined extends AuthState {
  const AuthUndetermined();

  @override
  bool operator ==(Object other) => other is AuthUndetermined;

  @override
  int get hashCode => (AuthUndetermined).hashCode;
}

class AuthWorking extends AuthState {
  const AuthWorking();

  @override
  bool operator ==(Object other) => other is AuthWorking;

  @override
  int get hashCode => (AuthWorking).hashCode;
}

class AuthSignedOut extends AuthState {
  const AuthSignedOut();

  @override
  bool operator ==(Object other) => other is AuthSignedOut;

  @override
  int get hashCode => (AuthSignedOut).hashCode;
}

class AuthSignedIn extends AuthState {
  final DropUser user;

  const AuthSignedIn(this.user);

  @override
  bool operator ==(Object other) => other is AuthSignedIn && other.user == user;

  @override
  int get hashCode => user.hashCode;
}

class AuthFailed extends AuthState {
  final String message;

  const AuthFailed(this.message);

  @override
  bool operator ==(Object other) =>
      other is AuthFailed && other.message == message;

  @override
  int get hashCode => message.hashCode;
}

class AuthStore {
  AuthState state = const AuthUndetermined();

  final AuthenticationGateway _gateway;
  final GoogleIdentityProvider _identityProvider;

  AuthStore({
    required this._gateway,
    required this._identityProvider,
  });

  DropUser? get user =>
      switch (state) { AuthSignedIn(:final user) => user, _ => null };

  /// 앱 시작 시 저장된 세션을 확인한다.
  Future<void> restore() async {
    final current = _gateway.currentUser;
    state = current != null ? AuthSignedIn(current) : const AuthSignedOut();
  }

  Future<void> signInWithGoogle() async {
    state = const AuthWorking();
    try {
      // null은 사용자가 창을 닫은 것 — 오류로 만들지 않는다.
      final identity = await _identityProvider.signIn();
      if (identity == null) {
        state = const AuthSignedOut();
        return;
      }
      final user = await _gateway.signIn(
        idToken: identity.idToken,
        accessToken: identity.accessToken,
      );
      state = AuthSignedIn(user);
    } catch (error) {
      state = AuthFailed(error.toString());
    }
  }

  Future<void> signOut() async {
    try {
      await _gateway.signOut();
    } catch (_) {
      // Supabase 쪽 로그아웃이 실패해도 로컬 세션은 끊어야 한다.
      // 여기서 멈추면 사용자가 로그아웃할 방법이 없어진다.
    }
    _identityProvider.signOut();
    state = const AuthSignedOut();
  }
}
