import Foundation

/// 노트에 달린 댓글. **노트가 아니다** — 태그·첨부·우선순위·보관·잠금이 없고,
/// 목록·검색·Inbox·위젯 어디에도 노트로 나타나지 않는다 (BRU-62의 별도 테이블 설계).
///
/// 소프트 삭제도 없다. 지우면 즉시 사라지고, 노트를 휴지통에 넣어도 댓글은 남는다.
public struct NoteComment: Sendable, Equatable, Identifiable, Codable {
    public let id: String
    public let noteID: String
    public let body: String
    public let createdAt: Date
    public let updatedAt: Date

    /// 디코더가 snake_case를 camelCase로 바꾼 뒤의 이름을 적는다 (`DropJSON.decoder`).
    private enum CodingKeys: String, CodingKey {
        case id
        case noteID = "noteId"
        case body
        case createdAt
        case updatedAt
    }

    public init(id: String, noteID: String, body: String, createdAt: Date, updatedAt: Date) {
        self.id = id
        self.noteID = noteID
        self.body = body
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
