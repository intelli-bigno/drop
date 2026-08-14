import Foundation

/// 앱이 알아듣는 링크. 여기서 nil이면 다른 처리기(Google 로그인 콜백 등)로 넘어간다.
public enum DropLink: Equatable, Sendable {
    case note(id: String)
    case compose(text: String?)

    /// 위젯이 여는 링크. 앱의 기존 작성 경로를 그대로 탄다 —
    /// 위젯 전용 라우팅을 따로 만들면 두 경로가 어긋난다.
    public static let quickComposeURL = URL(string: "drop://compose")!

    /// 위젯에서 특정 노트를 여는 링크.
    public static func noteURL(id: String) -> URL {
        URL(string: "drop://note/\(id)") ?? quickComposeURL
    }

    public init?(url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }

        guard let scheme = url.scheme?.lowercased() else { return nil }

        let pathSegments = components.path.split(separator: "/").map(String.init)
        let segments: [String]
        switch scheme {
        case "drop":
            // drop://note/ID 에서는 "note"가 host 자리에 온다.
            segments = ([components.host].compactMap { $0 } + pathSegments).filter { !$0.isEmpty }
        case "http", "https":
            // 웹 링크는 host가 도메인이므로 경로만 본다.
            guard components.host?.hasSuffix("intellieffect.com") == true else { return nil }
            segments = pathSegments
        default:
            return nil
        }

        switch segments.first {
        case "note":
            guard segments.count >= 2, !segments[1].isEmpty else { return nil }
            self = .note(id: segments[1])
        case "compose":
            let text = components.queryItems?.first { $0.name == "text" }?.value
            self = .compose(text: text)
        default:
            return nil
        }
    }
}
