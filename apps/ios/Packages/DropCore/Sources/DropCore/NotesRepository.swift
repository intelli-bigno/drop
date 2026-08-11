import Foundation

public enum NotesRepositoryError: Error, Equatable {
    case notAuthenticated
    case network(String)
    case decoding(String)
    case rejected(String)
}

/// 노트 데이터 접근 경계. 화면은 이 프로토콜만 알고, 테스트는 인메모리 구현을 쓴다.
public protocol NotesRepository: Sendable {
    /// 목록 전체를 한 번에 가져온다. 보관·휴지통까지 포함해 받고 화면에서 거른다 —
    /// Flutter 앱과 같은 방식이라 두 앱의 목록이 어긋나지 않는다.
    func loadNotes() async throws -> [Note]

    func createNote(content: String, parentID: String?) async throws -> Note
    func updateNote(id: String, content: String) async throws

    /// 휴지통으로 보낸다(soft delete). 보관 상태였다면 함께 해제한다.
    func moveToTrash(id: String) async throws
    func restoreFromTrash(id: String) async throws
    func archive(id: String) async throws
    func unarchive(id: String) async throws
    func deletePermanently(id: String) async throws
    func emptyTrash() async throws

    func setPinned(id: String, isPinned: Bool) async throws
    func setLocked(id: String, isLocked: Bool) async throws
    func setPriority(id: String, priority: Int) async throws
    func updateCategories(id: String, hasLink: Bool, hasMedia: Bool, hasFiles: Bool) async throws
}

public extension NotesRepository {
    func createNote(content: String = "") async throws -> Note {
        try await createNote(content: content, parentID: nil)
    }
}
