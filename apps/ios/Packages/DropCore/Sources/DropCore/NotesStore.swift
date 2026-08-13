import Foundation
import Observation

/// 홈 화면이 보는 상태 전부. Riverpod의 notesProvider + selection_provider +
/// 카테고리/뷰모드 필터를 하나로 합쳤다.
///
/// 목록은 보관·휴지통까지 통째로 받아 두고 화면에서 거른다 — Flutter와 같은 구조라
/// 두 앱의 목록이 어긋나지 않는다.
@MainActor
@Observable
public final class NotesStore {
    public private(set) var allNotes: [Note] = []
    public private(set) var isLoading = false
    public private(set) var errorMessage: String?

    public var viewMode: NoteViewMode = .active
    public var category: NoteCategory = .all
    public var selectedTagID: String?
    public var searchText: String = ""

    public private(set) var selectedIDs: Set<String> = []

    private let repository: any NotesRepository

    public init(repository: any NotesRepository) {
        self.repository = repository
    }

    public var isSelecting: Bool { !selectedIDs.isEmpty }

    public var visibleNotes: [Note] {
        allNotes.filter { note in
            guard note.matches(viewMode: viewMode), note.matches(category: category) else { return false }
            if let selectedTagID, !note.tags.contains(where: { $0.id == selectedTagID }) { return false }
            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !query.isEmpty, !note.content.localizedCaseInsensitiveContains(query) { return false }
            return true
        }
    }

    /// 지금 화면에 보이는 태그 목록 (필터 칩용).
    public var availableTags: [Tag] {
        var seen: Set<String> = []
        return allNotes.flatMap(\.tags).filter { seen.insert($0.id).inserted }
    }

    public func load() async {
        isLoading = true
        errorMessage = nil
        do {
            allNotes = try await repository.loadNotes()
        } catch where error.isCancellation {
            // 취소는 실패가 아니다. 보고 있던 목록을 그대로 둔다.
        } catch {
            allNotes = []
            errorMessage = Self.message(for: error)
        }
        isLoading = false
    }

    public func create(content: String) async {
        // 저장을 기다리지 않고 먼저 끼워 넣는다. 실패하면 걷어낸다 —
        // 남겨 두면 저장되지도 않은 노트가 목록에 남는다.
        let placeholder = Note(
            id: "임시-\(UUID().uuidString)",
            displayID: 0,
            content: content,
            createdAt: Date(),
            updatedAt: Date(),
            source: .mobile
        )
        allNotes.insert(placeholder, at: 0)

        do {
            let created = try await repository.createNote(content: content, parentID: nil)
            replace(id: placeholder.id, with: created)
        } catch {
            allNotes.removeAll { $0.id == placeholder.id }
            errorMessage = Self.message(for: error)
        }
    }

    public func update(id: String, content: String) async {
        await mutate(id: id, optimistic: { $0.replacing(content: content, updatedAt: Date()) }) {
            try await repository.updateNote(id: id, content: content)
        }
    }

    public func moveToTrash(id: String) async {
        await mutate(id: id, optimistic: { $0.replacing(archivedAt: Optional<Date>.none, deletedAt: Date()) }) {
            try await repository.moveToTrash(id: id)
        }
    }

    public func restore(id: String) async {
        await mutate(id: id, optimistic: { $0.replacing(deletedAt: Optional<Date>.none) }) {
            try await repository.restoreFromTrash(id: id)
        }
    }

    public func archive(id: String) async {
        await mutate(id: id, optimistic: { $0.replacing(archivedAt: Date()) }) {
            try await repository.archive(id: id)
        }
    }

    public func unarchive(id: String) async {
        await mutate(id: id, optimistic: { $0.replacing(archivedAt: Optional<Date>.none) }) {
            try await repository.unarchive(id: id)
        }
    }

    public func setPinned(id: String, isPinned: Bool) async {
        await mutate(
            id: id,
            optimistic: { $0.replacing(isPinned: isPinned, pinnedAt: isPinned ? Date() : nil) }
        ) {
            try await repository.setPinned(id: id, isPinned: isPinned)
        }
    }

    public func deletePermanently(id: String) async {
        let backup = allNotes
        allNotes.removeAll { $0.id == id }
        do {
            try await repository.deletePermanently(id: id)
        } catch {
            allNotes = backup
            errorMessage = Self.message(for: error)
        }
    }

    // MARK: - 선택 모드

    public func toggleSelection(id: String) {
        if selectedIDs.contains(id) {
            selectedIDs.remove(id)
        } else {
            selectedIDs.insert(id)
        }
    }

    public func clearSelection() {
        selectedIDs.removeAll()
    }

    public func dismissError() {
        errorMessage = nil
    }

    /// 화면 쪽(첨부 업로드 등)에서 생긴 오류도 같은 자리에 보여 준다.
    public func report(error: Error) {
        errorMessage = Self.message(for: error)
    }

    public func trashSelected() async {
        let targets = selectedIDs
        // 일괄 처리 전에 선택을 비운다. 남겨 두면 다음 탭이 엉뚱한 노트에 걸린다.
        clearSelection()
        for id in targets {
            await moveToTrash(id: id)
        }
    }

    public func deleteSelectedPermanently() async {
        let targets = selectedIDs
        clearSelection()
        for id in targets {
            await deletePermanently(id: id)
        }
    }

    // MARK: - 내부

    private func mutate(
        id: String,
        optimistic: (Note) -> Note,
        perform: () async throws -> Void
    ) async {
        guard let index = allNotes.firstIndex(where: { $0.id == id }) else { return }
        let backup = allNotes[index]
        allNotes[index] = optimistic(backup)
        allNotes = NoteAssembler.sorted(allNotes)

        do {
            try await perform()
        } catch {
            replace(id: id, with: backup)
            errorMessage = Self.message(for: error)
        }
    }

    private func replace(id: String, with note: Note) {
        guard let index = allNotes.firstIndex(where: { $0.id == id }) else { return }
        allNotes[index] = note
        allNotes = NoteAssembler.sorted(allNotes)
    }

    static func message(for error: Error) -> String {
        switch error {
        case NotesRepositoryError.notAuthenticated: "로그인이 필요합니다."
        case let NotesRepositoryError.rejected(reason): "서버가 요청을 거절했습니다: \(reason)"
        case NotesRepositoryError.network: "네트워크에 연결하지 못했습니다."
        case NotesRepositoryError.decoding: "응답을 이해하지 못했습니다."
        default: error.localizedDescription
        }
    }
}
