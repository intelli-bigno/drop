import Foundation
import Testing

@testable import DropCore

/// Riverpod의 notesProvider + selection_provider + 필터 상태를 하나로 합친 것.
@Suite("노트 목록 상태")
@MainActor
struct NotesStoreTests {
    private func store(_ notes: [Note] = []) -> (NotesStore, InMemoryNotesRepository) {
        let repository = InMemoryNotesRepository(notes: notes)
        return (NotesStore(repository: repository), repository)
    }

    private func note(
        _ id: String,
        content: String = "",
        created: TimeInterval = 0,
        archived: Bool = false,
        trashed: Bool = false,
        pinned: Bool = false,
        hasLink: Bool = false,
        tags: [String] = []
    ) -> Note {
        Note(
            id: id, displayID: 1, content: content,
            tags: tags.map { DropCore.Tag(id: $0, name: $0, createdAt: .distantPast) },
            createdAt: Date(timeIntervalSince1970: 1_700_000_000 + created),
            updatedAt: .distantPast, source: .mobile,
            archivedAt: archived ? .distantPast : nil,
            deletedAt: trashed ? .distantPast : nil,
            hasLink: hasLink, isPinned: pinned
        )
    }

    @Test("불러오면 목록이 채워진다")
    func loadsNotes() async {
        let (store, _) = store([note("a"), note("b")])

        await store.load()

        #expect(store.visibleNotes.count == 2)
        #expect(!store.isLoading)
    }

    @Test("실패하면 오류를 노출하고 목록은 비운다")
    func surfacesLoadFailure() async {
        let (store, repository) = store()
        repository.loadError = NotesRepositoryError.network("끊김")

        await store.load()

        #expect(store.errorMessage != nil)
        #expect(store.visibleNotes.isEmpty)
    }

    /// 보관·휴지통 노트도 함께 받아 화면에서 거른다 (Flutter와 같은 구조).
    @Test("뷰 모드가 목록을 가른다")
    func viewModeFiltersList() async {
        let (store, _) = store([note("활성"), note("보관", archived: true), note("휴지통", trashed: true)])
        await store.load()

        #expect(store.visibleNotes.map(\.id) == ["활성"])

        store.viewMode = .archived
        #expect(store.visibleNotes.map(\.id) == ["보관"])

        store.viewMode = .trash
        #expect(store.visibleNotes.map(\.id) == ["휴지통"])
    }

    @Test("카테고리 필터가 함께 걸린다")
    func categoryFilterStacks() async {
        let (store, _) = store([note("링크", hasLink: true), note("보통")])
        await store.load()

        store.category = .links

        #expect(store.visibleNotes.map(\.id) == ["링크"])
    }

    @Test("태그 필터는 선택한 태그를 가진 노트만 남긴다")
    func tagFilterNarrows() async {
        let (store, _) = store([note("일", tags: ["work"]), note("잡", tags: ["etc"])])
        await store.load()

        store.selectedTagID = "work"

        #expect(store.visibleNotes.map(\.id) == ["일"])
    }

    @Test("검색어는 본문에 걸린다")
    func searchMatchesContent() async {
        let (store, _) = store([note("a", content: "회의 준비"), note("b", content: "장보기")])
        await store.load()

        store.searchText = "회의"

        #expect(store.visibleNotes.map(\.id) == ["a"])
    }

    /// 새 노트는 저장을 기다리지 않고 목록에 먼저 들어간다.
    @Test("작성한 노트가 목록 맨 앞에 즉시 나타난다")
    func createInsertsImmediately() async {
        let (store, _) = store([note("기존", created: 0)])
        await store.load()

        await store.create(content: "새 노트")

        #expect(store.visibleNotes.first?.content == "새 노트")
        #expect(store.visibleNotes.count == 2)
    }

    /// 실패하면 끼워 넣은 노트를 걷어내야 한다. 안 그러면 새로고침 전까지
    /// 저장되지도 않은 노트가 목록에 남아 있게 된다.
    @Test("작성이 실패하면 끼워 넣은 노트를 되돌린다")
    func createRollsBackOnFailure() async {
        let (store, repository) = store([note("기존")])
        await store.load()
        repository.createError = NotesRepositoryError.rejected("거절")

        await store.create(content: "새 노트")

        #expect(store.visibleNotes.map(\.id) == ["기존"])
        #expect(store.errorMessage != nil)
    }

    @Test("휴지통으로 보내면 활성 목록에서 사라진다")
    func trashRemovesFromActiveList() async {
        let (store, _) = store([note("a"), note("b")])
        await store.load()

        await store.moveToTrash(id: "a")

        #expect(store.visibleNotes.map(\.id) == ["b"])
    }

    @Test("삭제가 실패하면 노트가 목록으로 돌아온다")
    func trashRollsBackOnFailure() async {
        let (store, repository) = store([note("a")])
        await store.load()
        repository.mutationError = NotesRepositoryError.network("끊김")

        await store.moveToTrash(id: "a")

        #expect(store.visibleNotes.map(\.id) == ["a"])
        #expect(store.errorMessage != nil)
    }

    @Test("선택 모드에서 여러 노트를 골라 한 번에 버린다")
    func bulkTrashSelected() async {
        let (store, _) = store([note("a"), note("b"), note("c")])
        await store.load()

        store.toggleSelection(id: "a")
        store.toggleSelection(id: "c")
        #expect(store.selectedIDs == ["a", "c"])

        await store.trashSelected()

        #expect(store.visibleNotes.map(\.id) == ["b"])
        // 일괄 처리가 끝나면 선택 모드에서 빠져나와야 한다 —
        // 선택이 남아 있으면 다음 탭이 엉뚱한 노트에 걸린다.
        #expect(store.selectedIDs.isEmpty)
        #expect(!store.isSelecting)
    }

    @Test("선택을 다시 누르면 해제된다")
    func toggleDeselects() async {
        let (store, _) = store([note("a")])
        await store.load()

        store.toggleSelection(id: "a")
        store.toggleSelection(id: "a")

        #expect(store.selectedIDs.isEmpty)
        #expect(!store.isSelecting)
    }

    @Test("고정하면 목록 맨 위로 올라간다")
    func pinMovesToTop() async {
        let (store, _) = store([note("a", created: 100), note("b", created: 0)])
        await store.load()

        await store.setPinned(id: "b", isPinned: true)

        #expect(store.visibleNotes.map(\.id) == ["b", "a"])
    }

    @Test("본문을 고치면 목록에 바로 반영된다")
    func updateReflectsImmediately() async {
        let (store, _) = store([note("a", content: "예전")])
        await store.load()

        await store.update(id: "a", content: "새 내용")

        #expect(store.visibleNotes.first?.content == "새 내용")
    }
}
