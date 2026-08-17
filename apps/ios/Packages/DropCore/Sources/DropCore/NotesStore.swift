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
    /// 지금 도는 로드. 겹친 호출은 새 요청을 보내지 않고 이것을 기다린다.
    private var inFlight: Task<Void, Never>?

    public init(repository: any NotesRepository) {
        self.repository = repository
    }

    public var isSelecting: Bool { !selectedIDs.isEmpty }

    /// 지금 탭(활성·보관·휴지통)과 카테고리에 속하는 노트 전부.
    /// 태그·검색으로 걸러지기 **전**이라, 답글의 부모를 맥락으로 끌어올 후보가 된다.
    public var scopedNotes: [Note] {
        allNotes.filter { $0.matches(viewMode: viewMode) && $0.matches(category: category) }
    }

    public var visibleNotes: [Note] {
        scopedNotes.filter { note in
            if let selectedTagID, !note.tags.contains(where: { $0.id == selectedTagID }) { return false }
            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !query.isEmpty, !note.content.localizedCaseInsensitiveContains(query) { return false }
            return true
        }
    }

    /// 화면이 그리는 것. 답글이 부모 아래로 묶이고 들여쓰기 단수까지 정해져 있다.
    ///
    /// 부모는 **같은 탭 안에서만** 끌어온다 — 보관함에 있는 부모를 활성 목록에
    /// 끌어오면 지운 셈 친 노트가 되살아난다.
    public var visibleRows: [NoteRow] {
        NoteHierarchy.rows(visible: visibleNotes, context: scopedNotes)
    }

    /// 지금 화면에 보이는 태그 목록 (필터 칩용).
    public var availableTags: [Tag] {
        var seen: Set<String> = []
        return allNotes.flatMap(\.tags).filter { seen.insert($0.id).inserted }
    }

    /// 목록을 다시 받아온다. 화면 진입(`.task`)과 당겨서 새로고침(`.refreshable`)이
    /// 같은 입구를 쓴다.
    ///
    /// 겹친 호출은 요청을 한 번만 보내되, **먼저 도는 로드가 끝날 때까지 기다린다.**
    /// 즉시 돌려보내면(예전 동작) 당겨서 새로고침은 스피너만 튕기고 아무 일도 하지
    /// 않은 것처럼 보인다 — `.refreshable`은 호출이 끝나는 순간 스피너를 접기 때문이다.
    ///
    /// 로드를 떼어 낸 Task에 담아 두는 이유도 같다. 당김 제스처가 끝나면서 SwiftUI가
    /// 새로고침 Task를 취소해도, 이미 시작한 로드는 끝까지 가서 목록을 갱신한다.
    public func load() async {
        if let inFlight {
            await inFlight.value
            return
        }

        let task = Task { [self] in
            await performLoad()
            inFlight = nil
        }
        inFlight = task
        await task.value
    }

    private func performLoad() async {
        isLoading = true
        errorMessage = nil
        do {
            allNotes = try await repository.loadNotes()
        } catch where error.isCancellation {
            // 취소는 실패가 아니다. 보고 있던 목록을 그대로 둔다.
        } catch {
            // 실패한 것은 "새 목록을 받아오는 일"이지 이미 받아 둔 목록이 아니다.
            // 여기서 목록을 비우면 당겨서 새로고침이 한 번 실패할 때마다 화면이
            // 통째로 사라진다 (BRU-51). 첫 로드라면 어차피 비어 있으니 잃을 것도 없다.
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
        RepositoryErrorMessage.text(for: error)
    }
}
