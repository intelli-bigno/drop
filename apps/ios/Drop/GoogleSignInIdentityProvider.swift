import DropCore
import GoogleSignIn
import UIKit

/// `GoogleIdentityProvider`의 실제 구현. 로그인 창을 띄우려면 표시 중인
/// view controller가 필요하기 때문에 DropCore가 아니라 앱 타겟에 있다.
@MainActor
final class GoogleSignInIdentityProvider: GoogleIdentityProvider {
    private let configuration: DropConfiguration

    init(configuration: DropConfiguration) {
        self.configuration = configuration

        // serverClientId에 **웹** 클라이언트 ID를 넘겨야 id_token의 audience가
        // 웹 클라이언트가 된다. 이걸 빠뜨리면 Supabase가 Unacceptable audience로 거부한다.
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(
            clientID: configuration.googleIOSClientID,
            serverClientID: configuration.googleWebClientID
        )
    }

    func signIn() async throws -> GoogleIdentity? {
        guard let presenter = Self.topViewController() else {
            throw GoogleSignInProviderError.noPresenter
        }

        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenter)
            guard let idToken = result.user.idToken?.tokenString else {
                throw GoogleSignInProviderError.missingIDToken
            }
            return GoogleIdentity(
                idToken: idToken,
                accessToken: result.user.accessToken.tokenString
            )
        } catch let error as NSError
            where error.domain == kGIDSignInErrorDomain
            && error.code == GIDSignInError.canceled.rawValue
        {
            // 사용자가 창을 닫았다 — 오류가 아니라 "아무 일도 없었음"이다.
            return nil
        }
    }

    func signOut() {
        GIDSignIn.sharedInstance.signOut()
    }

    private static func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        var top = scene?.keyWindow?.rootViewController
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }
}

enum GoogleSignInProviderError: LocalizedError {
    case noPresenter
    case missingIDToken

    var errorDescription: String? {
        switch self {
        case .noPresenter: "로그인 창을 띄울 화면을 찾지 못했습니다."
        case .missingIDToken: "Google이 ID 토큰을 주지 않았습니다."
        }
    }
}
