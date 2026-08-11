import Foundation

/// 테스트와 SwiftUI 프리뷰용 리포지토리. 네트워크 없이 같은 계약을 지킨다.
public final class InMemoryNotesRepository: NotesRepository, @unchecked Sendable {
    private let lock = NSLock()
    private var notes: [Note]

    /// 실패 경로를 시험하기 위한 손잡이.
    public var loadError: Error?
    public var createError: Error?
    public var mutationError: Error?

    public init(notes: [Note] = []) {
        self.notes = notes
    }

    public func loadNotes() async throws -> [Note] {
        if let loadError { throw loadError }
        return withLock { NoteAssembler.sorted(notes) }
    }

    public func createNote(content: String, parentID: String?) async throws -> Note {
        if let createError { throw createError }
        let note = Note(
            id: UUID().uuidString,
            displayID: withLock { notes.count } + 1,
            content: content,
            parentID: parentID,
            createdAt: Date(),
            updatedAt: Date(),
            source: .mobile
        )
        withLock { notes.insert(note, at: 0) }
        return note
    }

    public func updateNote(id: String, content: String) async throws {
        try mutate(id: id) { $0.replacing(content: content) }
    }

    public func moveToTrash(id: String) async throws {
        try mutate(id: id) { $0.replacing(archivedAt: Optional<Date>.none, deletedAt: Date()) }
    }

    public func restoreFromTrash(id: String) async throws {
        try mutate(id: id) { $0.replacing(deletedAt: Optional<Date>.none) }
    }

    public func archive(id: String) async throws {
        try mutate(id: id) { $0.replacing(archivedAt: Date()) }
    }

    public func unarchive(id: String) async throws {
        try mutate(id: id) { $0.replacing(archivedAt: Optional<Date>.none) }
    }

    public func deletePermanently(id: String) async throws {
        if let mutationError { throw mutationError }
        withLock { notes.removeAll { $0.id == id } }
    }

    public func emptyTrash() async throws {
        if let mutationError { throw mutationError }
        withLock { notes.removeAll { $0.isInTrash } }
    }

    public func setPinned(id: String, isPinned: Bool) async throws {
        try mutate(id: id) { $0.replacing(isPinned: isPinned, pinnedAt: isPinned ? Date() : nil) }
    }

    public func setLocked(id: String, isLocked: Bool) async throws {
        try mutate(id: id) { $0.replacing(isLocked: isLocked) }
    }

    public func setPriority(id: String, priority: Int) async throws {
        try mutate(id: id) { $0.replacing(priority: min(max(priority, 0), 3)) }
    }

    public func updateCategories(id: String, hasLink: Bool, hasMedia: Bool, hasFiles: Bool) async throws {
        try mutate(id: id) { $0.replacing(hasLink: hasLink, hasMedia: hasMedia, hasFiles: hasFiles) }
    }

    private func mutate(id: String, _ transform: (Note) -> Note) throws {
        if let mutationError { throw mutationError }
        withLock {
            guard let index = notes.firstIndex(where: { $0.id == id }) else { return }
            notes[index] = transform(notes[index])
        }
    }

    private func withLock<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }
}
