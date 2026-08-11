import Foundation
import Supabase

/// `AuthenticationGateway`의 실제 구현. Supabase 세션은 SDK가 Keychain에
/// 보관하므로 앱을 다시 켜면 `currentUser`로 복원된다.
@MainActor
public final class SupabaseAuthenticationGateway: AuthenticationGateway {
    private let client: SupabaseClient

    public init(client: SupabaseClient) {
        self.client = client
    }

    public var currentUser: DropUser? {
        client.auth.currentUser.map(DropUser.init(supabaseUser:))
    }

    public func signIn(idToken: String, accessToken: String?) async throws -> DropUser {
        let session = try await client.auth.signInWithIdToken(
            credentials: .init(provider: .google, idToken: idToken, accessToken: accessToken)
        )
        return DropUser(supabaseUser: session.user)
    }

    public func signOut() async throws {
        try await client.auth.signOut()
    }
}

extension DropUser {
    init(supabaseUser user: User) {
        self.init(id: user.id.uuidString, email: user.email)
    }
}
