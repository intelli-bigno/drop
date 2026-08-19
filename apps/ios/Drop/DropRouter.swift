import DropCore
import Observation
import SwiftUI

/// 딥링크로 들어온 요청을 화면이 집어 갈 때까지 들고 있는다.
///
/// 콜드 스타트에서는 링크가 화면보다 먼저 도착한다. 그래서 즉시 처리하지 않고
/// 보관해 두었다가, 홈이 나타난 뒤에 소비하게 한다.
@MainActor
@Observable
final class DropRouter {
    /// 위젯에서 들어온 사진 첨부 요청 (BRU-43). 카메라·갤러리는 여는 창만 다르고
    /// 그 뒤는 앱의 기존 사진 첨부 경로를 그대로 탄다.
    enum QuickCapture: Equatable {
        case camera
        case gallery
    }

    private(set) var pendingNoteID: String?
    private(set) var pendingComposeText: String?
    private(set) var pendingCapture: QuickCapture?

    func handle(_ link: DropLink) {
        switch link {
        case let .note(id):
            pendingNoteID = id
        case let .compose(text):
            pendingComposeText = text ?? ""
        case .camera:
            pendingCapture = .camera
        case .gallery:
            pendingCapture = .gallery
        }
    }

    func consumeNoteID() -> String? {
        defer { pendingNoteID = nil }
        return pendingNoteID
    }

    func consumeComposeText() -> String? {
        defer { pendingComposeText = nil }
        return pendingComposeText
    }

    func consumeCapture() -> QuickCapture? {
        defer { pendingCapture = nil }
        return pendingCapture
    }
}
