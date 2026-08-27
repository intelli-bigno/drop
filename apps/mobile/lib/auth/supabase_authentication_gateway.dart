/// drop_core 인증 경계의 Supabase 구현.
/// iOS `SupabaseAuthenticationGateway`(DropCore) 대응.
library;

import 'package:drop_core/drop_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

/// Google id_token을 Supabase 세션으로 바꾼다. 세션 저장·복원은
/// supabase_flutter가 맡는다 — `Supabase.initialize`가 저장된 세션을 되살리고,
/// [currentUser]는 그 결과를 읽는다.
class SupabaseAuthenticationGateway implements AuthenticationGateway {
  final supabase.GoTrueClient _auth;

  SupabaseAuthenticationGateway(this._auth);

  @override
  DropUser? get currentUser => _toDropUser(_auth.currentUser);

  @override
  Future<DropUser> signIn({required String idToken, String? accessToken}) async {
    final response = await _auth.signInWithIdToken(
      provider: supabase.OAuthProvider.google,
      idToken: idToken,
      accessToken: accessToken,
    );
    final user = _toDropUser(response.user);
    if (user == null) {
      throw StateError('Supabase가 사용자 없이 로그인 응답을 돌려주었습니다.');
    }
    return user;
  }

  @override
  Future<void> signOut() => _auth.signOut();

  static DropUser? _toDropUser(supabase.User? user) =>
      user == null ? null : DropUser(id: user.id, email: user.email);
}

/// drop_core REST 리포지토리가 묻는 "지금 누구·무슨 토큰" —
/// supabase_flutter의 살아 있는 세션에서 매 호출 시점에 꺼낸다.
/// 미리 붙잡아 두면 만료된 토큰을 계속 쓰게 된다.
class SupabaseFlutterSessionProvider implements SupabaseSessionProvider {
  final supabase.GoTrueClient _auth;

  SupabaseFlutterSessionProvider(this._auth);

  @override
  String? get currentUserId => _auth.currentUser?.id;

  @override
  String? get accessToken => _auth.currentSession?.accessToken;
}
