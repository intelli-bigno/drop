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
    private(set) var pendingNoteID: String?
    private(set) var pendingComposeText: String?

    func handle(_ link: DropLink) {
        switch link {
        case let .note(id):
            pendingNoteID = id
        case let .compose(text):
            pendingComposeText = text ?? ""
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
}
