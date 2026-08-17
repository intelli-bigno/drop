import Foundation

/// 테스트와 프리뷰(`-dropPreview`)용 리포지토리. 네트워크 없이 같은 계약을 지킨다.
public final class InMemoryCommentsRepository: CommentsRepository, @unchecked Sendable {
    private let lock = NSLock()
    private var comments: [NoteComment]

    /// 실패 경로를 시험하기 위한 손잡이.
    public var loadError: Error?
    public var createError: Error?
    public var mutationError: Error?

    /// 로드를 원하는 시점까지 붙잡아 두기 위한 손잡이 — 겹친 로드를 재현한다.
    public var beforeLoad: (@Sendable () async -> Void)?

    public private(set) var loadCallCount = 0
    public private(set) var createCallCount = 0
    /// 다듬기(trim)가 실제로 걸렸는지 보기 위한 것.
    public private(set) var lastCreatedBody: String?

    public init(comments: [NoteComment] = []) {
        self.comments = comments
    }

    public func loadComments(noteID: String) async throws -> [NoteComment] {
        withLock { loadCallCount += 1 }
        await beforeLoad?()
        if let loadError { throw loadError }
        return withLock {
            comments.filter { $0.noteID == noteID }.sorted { $0.createdAt < $1.createdAt }
        }
    }

    public func loadCommentCounts() async throws -> [String: Int] {
        if let loadError { throw loadError }
        return withLock {
            comments.reduce(into: [:]) { counts, comment in
                counts[comment.noteID, default: 0] += 1
            }
        }
    }

    public func createComment(noteID: String, body: String) async throws -> NoteComment {
        withLock {
            createCallCount += 1
            lastCreatedBody = body
        }
        if let createError { throw createError }
        let comment = NoteComment(
            id: UUID().uuidString,
            noteID: noteID,
            body: body,
            createdAt: Date(),
            updatedAt: Date()
        )
        withLock { comments.append(comment) }
        return comment
    }

    public func deleteComment(id: String) async throws {
        if let mutationError { throw mutationError }
        withLock { comments.removeAll { $0.id == id } }
    }

    private func withLock<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }
}
