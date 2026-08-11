import Foundation

/// 앱이 어느 Supabase를 보는지.
///
/// 데스크톱(`apps/desktop`)의 `--mode localdev` / `--mode remote`와 같은 개념이다.
public enum DropEnvironment: String, Sendable {
    case localdev
    case remote
}

public enum DropConfigurationError: Error, Equatable {
    /// 키가 아예 없거나, 공백뿐인 값이 들어왔다.
    case missingValue(String)
    case malformedURL(String)
    /// 웹 클라이언트 ID 자리에 iOS 클라이언트 ID를 넣은 경우.
    case webAndIOSClientIDsIdentical
}

/// 빌드 구성값. xcconfig → Info.plist → 이 타입 순으로 흘러온다.
///
/// Info.plist를 읽는 지점을 사전 하나로 좁혀 두어, 번들 없이도 테스트할 수 있게 했다.
public struct DropConfiguration: Sendable, Equatable {
    public let supabaseURL: URL
    public let supabaseAnonKey: String
    public let environment: DropEnvironment

    /// Google 로그인 시 `serverClientId`로 넘길 값. **웹** 클라이언트 ID여야 한다 —
    /// Supabase Google provider가 audience로 신뢰하는 것이 웹 클라이언트 하나뿐이다.
    public let googleWebClientID: String
    /// 이 앱 자신의 클라이언트 ID.
    public let googleIOSClientID: String

    public init(plist: [String: Any]) throws {
        let urlString = try Self.requireValue(plist, key: "SUPABASE_URL")

        // 스킴이 없으면 URL(string:)이 상대 경로로 받아들여 조용히 통과한다.
        // xcconfig가 `//`를 주석으로 먹는 탓에 스킴이 잘린 값이 들어오는 사고가 잦아,
        // 여기서 확실히 끊는다.
        guard let url = URL(string: urlString), url.scheme != nil, url.host != nil else {
            throw DropConfigurationError.malformedURL(urlString)
        }

        self.supabaseURL = url
        self.supabaseAnonKey = try Self.requireValue(plist, key: "SUPABASE_ANON_KEY")
        self.environment = (plist["DROP_ENVIRONMENT"] as? String)
            .flatMap { DropEnvironment(rawValue: $0.trimmingCharacters(in: .whitespaces)) } ?? .localdev

        let webClientID = try Self.requireValue(plist, key: "GOOGLE_WEB_CLIENT_ID")
        let iosClientID = try Self.requireValue(plist, key: "GOOGLE_IOS_CLIENT_ID")

        // 같은 값이면 웹 자리에 iOS 것을 넣은 것이다. 그대로 두면 id_token의
        // audience가 iOS 클라이언트가 되어 Supabase가 Unacceptable audience로 거부한다.
        guard webClientID != iosClientID else {
            throw DropConfigurationError.webAndIOSClientIDsIdentical
        }

        self.googleWebClientID = webClientID
        self.googleIOSClientID = iosClientID
    }

    /// 앱 번들의 Info.plist에서 읽는다.
    public init(bundle: Bundle = .main) throws {
        try self.init(plist: bundle.infoDictionary ?? [:])
    }

    private static func requireValue(_ plist: [String: Any], key: String) throws -> String {
        guard
            let raw = plist[key] as? String,
            case let value = raw.trimmingCharacters(in: .whitespacesAndNewlines),
            !value.isEmpty
        else {
            throw DropConfigurationError.missingValue(key)
        }
        return value
    }
}
