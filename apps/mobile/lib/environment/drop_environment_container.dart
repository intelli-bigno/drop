/// 앱이 살아 있는 동안 공유하는 의존성 묶음.
/// iOS `DropCore/DropEnvironmentContainer.swift` 대응.
///
/// 전역 싱글턴(`Supabase.instance`)을 화면이 직접 찾지 않는 이유는 하나다 —
/// 테스트·프리뷰에서 갈아끼울 수 없기 때문이다. 앱 진입점에서 한 번 만들어
/// Riverpod `dropContainerProvider`로 흘려보낸다.
library;

import 'package:drop_core/drop_core.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../auth/google_sign_in_identity_provider.dart';
import '../auth/supabase_authentication_gateway.dart';
import '../preview/preview_launch.dart';

class DropEnvironmentContainer {
  /// 프리뷰 모드에는 구성이 없다 — 네트워크에 나가지 않는다.
  final DropConfiguration? configuration;

  /// `--dart-define=DROP_PREVIEW=true` 경로. 인증을 건너뛰고 인메모리 표본을 쓴다.
  final bool isPreview;

  final NotesRepository notesRepository;
  final CommentsRepository commentsRepository;
  final AuthenticationGateway authenticationGateway;
  final GoogleIdentityProvider identityProvider;

  DropEnvironmentContainer({
    required this.configuration,
    required this.isPreview,
    required this.notesRepository,
    required this.commentsRepository,
    required this.authenticationGateway,
    required this.identityProvider,
  });

  /// 자격증명 없는 프리뷰 조립 (iOS `-dropPreview` + `PreviewLaunch` 대응).
  factory DropEnvironmentContainer.preview() => DropEnvironmentContainer(
        configuration: null,
        isPreview: true,
        notesRepository: PreviewLaunch.makeNotesRepository(),
        commentsRepository: PreviewLaunch.makeCommentsRepository(),
        authenticationGateway: const _PreviewAuthenticationGateway(),
        identityProvider: const _PreviewIdentityProvider(),
      );

  /// 실제 Supabase 조립. [auth]는 `Supabase.initialize` 뒤의
  /// `Supabase.instance.client.auth` — 세션 저장·복원은 supabase_flutter 몫이고,
  /// REST 리포지토리는 매 호출 시점에 그 세션에서 토큰을 꺼낸다.
  factory DropEnvironmentContainer.live({
    required DropConfiguration configuration,
    required supabase.GoTrueClient auth,
  }) {
    final restClient = SupabaseRestClient(
      httpClient: http.Client(),
      baseUrl: configuration.supabaseUrl,
      anonKey: configuration.supabaseAnonKey,
      session: SupabaseFlutterSessionProvider(auth),
    );
    return DropEnvironmentContainer(
      configuration: configuration,
      isPreview: false,
      notesRepository: SupabaseNotesRepository(client: restClient),
      commentsRepository: SupabaseCommentsRepository(client: restClient),
      authenticationGateway: SupabaseAuthenticationGateway(auth),
      identityProvider: GoogleSignInIdentityProvider(configuration: configuration),
    );
  }
}

/// 프리뷰에서 인증 게이트는 아예 그려지지 않지만, AuthStore 조립 자체는
/// 무해하게 성립해야 한다 — 고정 사용자를 돌려준다.
class _PreviewAuthenticationGateway implements AuthenticationGateway {
  const _PreviewAuthenticationGateway();

  static const _user = DropUser(id: 'preview-user', email: 'preview@drop.local');

  @override
  DropUser? get currentUser => _user;

  @override
  Future<DropUser> signIn({required String idToken, String? accessToken}) async =>
      _user;

  @override
  Future<void> signOut() async {}
}

class _PreviewIdentityProvider implements GoogleIdentityProvider {
  const _PreviewIdentityProvider();

  @override
  Future<GoogleIdentity?> signIn() async => null;

  @override
  void signOut() {}
}
