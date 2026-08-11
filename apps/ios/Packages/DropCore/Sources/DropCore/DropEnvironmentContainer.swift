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

    /// 구성값으로 실제 Supabase 클라이언트를 만든다.
    public convenience init(configuration: DropConfiguration) {
        self.init(
            configuration: configuration,
            supabase: SupabaseClient(
                supabaseURL: configuration.supabaseURL,
                supabaseKey: configuration.supabaseAnonKey
            )
        )
    }

    /// 앱 번들의 Info.plist를 읽어 조립한다. 구성이 틀렸으면 여기서 즉시 죽는다 —
    /// 잘못된 구성으로 실행을 계속하면 "로그인이 안 된다" 같은 엉뚱한 증상으로 나타난다.
    public static func live(bundle: Bundle = .main) throws -> DropEnvironmentContainer {
        DropEnvironmentContainer(configuration: try DropConfiguration(bundle: bundle))
    }
}
