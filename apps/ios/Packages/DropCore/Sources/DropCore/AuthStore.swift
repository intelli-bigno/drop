import Foundation
import Observation

public struct DropUser: Sendable, Equatable, Identifiable {
    public let id: String
    public let email: String?

    public init(id: String, email: String?) {
        self.id = id
        self.email = email
    }
}

/// Google에서 받아온 자격증명. 화면(presenting view controller)이 필요한 SDK 호출은
/// 앱 타겟이 맡고, DropCore는 결과 토큰만 받는다.
public struct GoogleIdentity: Sendable, Equatable {
    public let idToken: String
    public let accessToken: String?

    public init(idToken: String, accessToken: String?) {
        self.idToken = idToken
        self.accessToken = accessToken
    }
}

/// Google 로그인 창을 띄우는 쪽. `nil` 반환은 **사용자 취소**를 뜻한다.
@MainActor
public protocol GoogleIdentityProvider {
    func signIn() async throws -> GoogleIdentity?
    func signOut()
}

/// Supabase 인증에 대한 얇은 경계. 테스트에서 통째로 갈아끼운다.
@MainActor
public protocol AuthenticationGateway {
    var currentUser: DropUser? { get }
    func signIn(idToken: String, accessToken: String?) async throws -> DropUser
    func signOut() async throws
}

public enum AuthState: Equatable, Sendable {
    /// 아직 세션을 확인하기 전. 이 상태에서 로그인 화면을 띄우면
    /// 이미 로그인된 사용자에게 로그인 화면이 깜빡인다.
    case undetermined
    case working
    case signedOut
    case signedIn(DropUser)
    case failed(String)
}

/// Riverpod `AuthNotifier`에 대응한다.
@MainActor
@Observable
public final class AuthStore {
    public private(set) var state: AuthState = .undetermined

    private let gateway: any AuthenticationGateway
    private let identityProvider: any GoogleIdentityProvider

    public init(gateway: any AuthenticationGateway, identityProvider: any GoogleIdentityProvider) {
        self.gateway = gateway
        self.identityProvider = identityProvider
    }

    public var user: DropUser? {
        if case let .signedIn(user) = state { return user }
        return nil
    }

    /// 앱 시작 시 저장된 세션을 확인한다.
    public func restore() async {
        state = gateway.currentUser.map(AuthState.signedIn) ?? .signedOut
    }

    public func signInWithGoogle() async {
        state = .working
        do {
            // nil은 사용자가 창을 닫은 것 — 오류로 만들지 않는다.
            guard let identity = try await identityProvider.signIn() else {
                state = .signedOut
                return
            }
            let user = try await gateway.signIn(
                idToken: identity.idToken,
                accessToken: identity.accessToken
            )
            state = .signedIn(user)
        } catch {
            state = .failed(String(describing: error))
        }
    }

    public func signOut() async {
        do {
            try await gateway.signOut()
        } catch {
            // Supabase 쪽 로그아웃이 실패해도 로컬 세션은 끊어야 한다.
            // 여기서 멈추면 사용자가 로그아웃할 방법이 없어진다.
        }
        identityProvider.signOut()
        state = .signedOut
    }
}
