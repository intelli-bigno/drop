import Foundation
import Supabase

/// 앱이 살아 있는 동안 공유하는 의존성 묶음.
///
/// `Supabase.instance` 같은 전역 싱글턴을 쓰지 않는 이유는 하나다 — 테스트에서
/// 갈아끼울 수 없기 때문이다. 앱 진입점에서 한 번 만들어 SwiftUI 환경으로 흘려보낸다.
public final class DropEnvironmentContainer: Sendable {
    public let configuration: DropConfiguration
    public let supabase: SupabaseClient

    public init(configuration: DropConfiguration, supabase: SupabaseClient) {
        self.configuration = configuration
        self.supabase = supabase
    }

    /// Supabase 인증 게이트웨이. 로그인 창을 띄우는 쪽(GoogleIdentityProvider)은
    /// 화면이 필요하므로 앱 타겟에서 주입한다.
    public func makeNotesRepository() -> any NotesRepository {
        SupabaseNotesRepository(client: supabase)
    }

    public func makeTagsRepository() -> any TagsRepository {
        SupabaseTagsRepository(client: supabase)
    }

    public func makeAttachmentsRepository() -> any AttachmentsRepository {
        SupabaseAttachmentsRepository(client: supabase)
    }

    @MainActor
    public func makeAuthStore(identityProvider: any GoogleIdentityProvider) -> AuthStore {
        AuthStore(
            gateway: SupabaseAuthenticationGateway(client: supabase),
            identityProvider: identityProvider
        )
    }

    /// 구성값으로 실제 Supabase 클라이언트를 만든다.
    public convenience init(configuration: DropConfiguration) {
        self.init(
            configuration: configuration,
            supabase: SupabaseClient(
                supabaseURL: configuration.supabaseURL,
                supabaseKey: configuration.supabaseAnonKey,
                options: SupabaseClientOptions(
                    // SDK 기본 디코더는 우리 모델이 기대하는 snake_case 변환과
                    // 분수초 있는/없는 timestamptz 처리를 하지 않는다. 반드시 갈아끼운다.
                    db: SupabaseClientOptions.DatabaseOptions(
                        encoder: DropJSON.encoder,
                        decoder: DropJSON.decoder
                    )
                )
            )
        )
    }

    /// 앱 번들의 Info.plist를 읽어 조립한다. 구성이 틀렸으면 여기서 즉시 죽는다 —
    /// 잘못된 구성으로 실행을 계속하면 "로그인이 안 된다" 같은 엉뚱한 증상으로 나타난다.
    public static func live(bundle: Bundle = .main) throws -> DropEnvironmentContainer {
        DropEnvironmentContainer(configuration: try DropConfiguration(bundle: bundle))
    }
}
