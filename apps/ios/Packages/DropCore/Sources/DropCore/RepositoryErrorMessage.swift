import Foundation

/// 리포지토리 오류를 화면에 띄울 문장으로 바꾼다.
///
/// `NotesStore` 안에 있던 것을 꺼냈다 — 상태(store)마다 같은 오류를 다른 말로
/// 보여 주면 같은 장애가 화면에 따라 달라 보인다.
enum RepositoryErrorMessage {
    static func text(for error: Error) -> String {
        switch error {
        case NotesRepositoryError.notAuthenticated: "로그인이 필요합니다."
        case let NotesRepositoryError.rejected(reason): "서버가 요청을 거절했습니다: \(reason)"
        case NotesRepositoryError.network: "네트워크에 연결하지 못했습니다."
        case NotesRepositoryError.decoding: "응답을 이해하지 못했습니다."
        default: error.localizedDescription
        }
    }
}
