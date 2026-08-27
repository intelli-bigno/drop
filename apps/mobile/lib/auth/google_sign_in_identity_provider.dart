/// `GoogleIdentityProvider`의 실제 구현.
/// iOS `Drop/GoogleSignInIdentityProvider.swift` 대응.
library;

import 'dart:async';

import 'package:drop_core/drop_core.dart';
// drop_core의 GoogleIdentity(우리 경계 타입)와 이름이 겹친다 — SDK 쪽을 숨긴다.
import 'package:google_sign_in/google_sign_in.dart' hide GoogleIdentity;

class GoogleSignInIdentityProvider implements GoogleIdentityProvider {
  final GoogleSignIn _googleSignIn;

  /// `serverClientId`에 **웹** 클라이언트 ID를 넘겨야 id_token의 audience가
  /// 웹 클라이언트가 된다. 이걸 빠뜨리면 Supabase가 Unacceptable audience로
  /// 거부한다 (PR #17 실증).
  GoogleSignInIdentityProvider({required DropConfiguration configuration})
      : _googleSignIn = GoogleSignIn(
          clientId: configuration.googleIosClientId,
          serverClientId: configuration.googleWebClientId,
          scopes: const ['email'],
        );

  @override
  Future<GoogleIdentity?> signIn() async {
    // null은 사용자가 창을 닫은 것 — 오류가 아니라 "아무 일도 없었음"이다.
    final account = await _googleSignIn.signIn();
    if (account == null) return null;

    final authentication = await account.authentication;
    final idToken = authentication.idToken;
    if (idToken == null) {
      throw StateError('Google이 ID 토큰을 주지 않았습니다.');
    }
    return GoogleIdentity(
      idToken: idToken,
      accessToken: authentication.accessToken,
    );
  }

  @override
  void signOut() {
    // AuthStore가 이 결과를 기다리지 않는다 — 로컬 세션을 끊는 게 우선이고,
    // Google 쪽 로그아웃은 다음 로그인에서 계정 선택을 다시 띄우기 위한 것뿐이다.
    unawaited(_googleSignIn.signOut());
  }
}
