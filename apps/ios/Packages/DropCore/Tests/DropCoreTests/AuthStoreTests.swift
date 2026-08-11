import Foundation
import Testing

@testable import DropCore

/// Riverpod `AuthNotifier`가 하던 상태 전이를 옮긴 것.
/// 실제 Google / Supabase 없이 게이트웨이를 갈아끼워 검증한다.
@Suite("인증 상태 전이")
@MainActor
struct AuthStoreTests {
    private func makeStore(
        gateway: FakeAuthenticationGateway = .init(),
        identity: FakeGoogleIdentityProvider = .init()
    ) -> (AuthStore, FakeAuthenticationGateway, FakeGoogleIdentityProvider) {
        (AuthStore(gateway: gateway, identityProvider: identity), gateway, identity)
    }

    @Test("시작 상태는 판단 보류다")
    func startsUnknown() {
        let (store, _, _) = makeStore()
        #expect(store.state == .undetermined)
    }

    @Test("기존 세션이 있으면 복원한다")
    func restoresExistingSession() async {
        let gateway = FakeAuthenticationGateway()
        gateway.currentUser = DropUser(id: "u1", email: "bruce@intellieffect.com")
        let (store, _, _) = makeStore(gateway: gateway)

        await store.restore()

        #expect(store.state == .signedIn(DropUser(id: "u1", email: "bruce@intellieffect.com")))
    }

    @Test("세션이 없으면 로그아웃 상태다")
    func noSessionMeansSignedOut() async {
        let (store, _, _) = makeStore()

        await store.restore()

        #expect(store.state == .signedOut)
    }

    @Test("로그인에 성공하면 사용자를 노출한다")
    func signInSucceeds() async {
        let identity = FakeGoogleIdentityProvider()
        identity.result = .success(GoogleIdentity(idToken: "id", accessToken: "access"))
        let gateway = FakeAuthenticationGateway()
        gateway.signInResult = .success(DropUser(id: "u2", email: "a@b.c"))
        let (store, _, _) = makeStore(gateway: gateway, identity: identity)

        await store.signInWithGoogle()

        #expect(store.state == .signedIn(DropUser(id: "u2", email: "a@b.c")))
        #expect(gateway.receivedIDToken == "id")
        #expect(gateway.receivedAccessToken == "access")
    }

    /// 사용자가 로그인 창을 닫은 것은 오류가 아니다.
    /// Flutter 쪽도 취소를 AsyncData(null)로 되돌린다 — 같은 동작을 유지한다.
    @Test("사용자가 취소하면 오류가 아니라 로그아웃으로 되돌린다")
    func cancellationIsNotAnError() async {
        let identity = FakeGoogleIdentityProvider()
        identity.result = .success(nil)
        let (store, _, _) = makeStore(identity: identity)

        await store.signInWithGoogle()

        #expect(store.state == .signedOut)
    }

    @Test("로그인이 실패하면 메시지를 남긴다")
    func signInFailureSurfacesMessage() async {
        let identity = FakeGoogleIdentityProvider()
        identity.result = .success(GoogleIdentity(idToken: "id", accessToken: nil))
        let gateway = FakeAuthenticationGateway()
        gateway.signInResult = .failure(TestError.boom)
        let (store, _, _) = makeStore(gateway: gateway, identity: identity)

        await store.signInWithGoogle()

        guard case .failed = store.state else {
            Issue.record("실패 상태가 아니라 \(store.state)")
            return
        }
    }

    @Test("로그아웃하면 Google 세션까지 함께 끊는다")
    func signOutClearsBothSides() async {
        let identity = FakeGoogleIdentityProvider()
        identity.result = .success(GoogleIdentity(idToken: "id", accessToken: nil))
        let gateway = FakeAuthenticationGateway()
        gateway.signInResult = .success(DropUser(id: "u3", email: nil))
        let (store, _, _) = makeStore(gateway: gateway, identity: identity)
        await store.signInWithGoogle()

        await store.signOut()

        #expect(store.state == .signedOut)
        #expect(gateway.signOutCallCount == 1)
        #expect(identity.signOutCallCount == 1)
    }

    /// 실패한 뒤 다시 시도하면 이전 오류 메시지가 남아 있으면 안 된다.
    @Test("재시도하면 이전 오류 표시가 사라진다")
    func retryClearsPreviousFailure() async {
        let identity = FakeGoogleIdentityProvider()
        identity.result = .success(GoogleIdentity(idToken: "id", accessToken: nil))
        let gateway = FakeAuthenticationGateway()
        gateway.signInResult = .failure(TestError.boom)
        let (store, _, _) = makeStore(gateway: gateway, identity: identity)
        await store.signInWithGoogle()

        gateway.signInResult = .success(DropUser(id: "u4", email: nil))
        await store.signInWithGoogle()

        #expect(store.state == .signedIn(DropUser(id: "u4", email: nil)))
    }
}

private enum TestError: Error { case boom }

@MainActor
private final class FakeAuthenticationGateway: AuthenticationGateway {
    var currentUser: DropUser?
    var signInResult: Result<DropUser, Error> = .failure(TestError.boom)
    private(set) var receivedIDToken: String?
    private(set) var receivedAccessToken: String?
    private(set) var signOutCallCount = 0

    func signIn(idToken: String, accessToken: String?) async throws -> DropUser {
        receivedIDToken = idToken
        receivedAccessToken = accessToken
        return try signInResult.get()
    }

    func signOut() async throws {
        signOutCallCount += 1
        currentUser = nil
    }
}

@MainActor
private final class FakeGoogleIdentityProvider: GoogleIdentityProvider {
    var result: Result<GoogleIdentity?, Error> = .success(nil)
    private(set) var signOutCallCount = 0

    func signIn() async throws -> GoogleIdentity? {
        try result.get()
    }

    func signOut() {
        signOutCallCount += 1
    }
}
