import Foundation
import Testing

@testable import DropCore

/// 열어 줄 때까지 기다리게 하는 문. 겹친 로드를 결정적으로 재현하기 위한 것 —
/// 시간(sleep)에 기대면 느린 기계에서 흔들린다. (NotesStoreTests와 같은 장치)
private actor Gate {
    private var isOpen = false
    private var waiting: [CheckedContinuation<Void, Never>] = []

    func wait() async {
        if isOpen { return }
        await withCheckedContinuation { waiting.append($0) }
    }

    func open() {
        isOpen = true
        for continuation in waiting { continuation.resume() }
        waiting.removeAll()
    }
}

@MainActor
private final class Flag {
    var isOn = false
}

/// 댓글은 노트가 아니다 — 목록·검색·위젯이 보는 `NotesStore`와 완전히 분리된
/// 자기 상태를 가진다. 여기서 검증하는 것은 그 상태의 규칙이다.
@Suite("노트 댓글 상태")
@MainActor
struct CommentsStoreTests {
    private func store(
        _ comments: [NoteComment] = []
    ) -> (CommentsStore, InMemoryCommentsRepository) {
        let repository = InMemoryCommentsRepository(comments: comments)
        return (CommentsStore(repository: repository), repository)
    }

    private func comment(
        _ id: String,
        noteID: String = "note-1",
        body: String = "댓글",
        created: TimeInterval = 0
    ) -> NoteComment {
        NoteComment(
            id: id,
            noteID: noteID,
            body: body,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000 + created),
            updatedAt: Date(timeIntervalSince1970: 1_700_000_000 + created)
        )
    }

    // MARK: - 로드

    /// 댓글은 대화다 — 오래된 것이 위, 새 것이 아래.
    @Test("불러오면 오래된 순으로 채워진다")
    func loadsCommentsOldestFirst() async {
        let (store, _) = store([comment("b", created: 100), comment("a", created: 0)])

        await store.load(noteID: "note-1")

        #expect(store.comments(for: "note-1").map(\.id) == ["a", "b"])
        #expect(!store.isLoading)
    }

    @Test("다른 노트의 댓글은 섞이지 않는다")
    func keepsCommentsPerNote() async {
        let (store, _) = store([comment("a", noteID: "note-1"), comment("b", noteID: "note-2")])

        await store.load(noteID: "note-1")

        #expect(store.comments(for: "note-1").map(\.id) == ["a"])
        #expect(store.comments(for: "note-2").isEmpty)
    }

    @Test("첫 로드가 실패하면 오류를 노출한다")
    func surfacesLoadFailure() async {
        let (store, repository) = store()
        repository.loadError = NotesRepositoryError.network("끊김")

        await store.load(noteID: "note-1")

        #expect(store.errorMessage != nil)
        #expect(store.comments(for: "note-1").isEmpty)
    }

    /// BRU-51 규칙. 실패한 것은 "새 목록을 받아오는 일"이지 이미 받아 둔 목록이 아니다.
    @Test("다시 불러오기가 실패해도 보고 있던 댓글은 남는다")
    func failedReloadKeepsComments() async {
        let (store, repository) = store([comment("a"), comment("b", created: 10)])
        await store.load(noteID: "note-1")

        repository.loadError = NotesRepositoryError.network("끊김")
        await store.load(noteID: "note-1")

        #expect(store.errorMessage != nil)
        #expect(store.comments(for: "note-1").map(\.id) == ["a", "b"])
    }

    @Test("취소된 로드는 오류가 아니다")
    func cancelledLoadIsNotAFailure() async {
        let (store, repository) = store([comment("a")])
        await store.load(noteID: "note-1")

        repository.loadError = CancellationError()
        await store.load(noteID: "note-1")

        #expect(store.errorMessage == nil)
        #expect(store.comments(for: "note-1").map(\.id) == ["a"])
    }

    @Test("URLError.cancelled도 취소로 본다")
    func cancelledURLErrorIsNotAFailure() async {
        let (store, repository) = store([comment("a")])
        await store.load(noteID: "note-1")

        repository.loadError = URLError(.cancelled)
        await store.load(noteID: "note-1")

        #expect(store.errorMessage == nil)
        #expect(store.comments(for: "note-1").map(\.id) == ["a"])
    }

    /// 화면 진입(`.task`)과 당겨서 새로고침이 겹칠 수 있다. 요청은 한 번만 보내되
    /// **먼저 도는 로드가 끝날 때까지 기다린다** — 즉시 돌아오면 새로고침 스피너가
    /// 아무 일도 하지 않은 채 접힌다 (BRU-51, NotesStore.load()와 같은 규칙).
    @Test("로드 중에 다시 부르면 그 로드가 끝날 때까지 기다린다")
    func overlappingLoadWaitsForTheOneInFlight() async {
        let (store, repository) = store([comment("a")])
        let gate = Gate()
        repository.beforeLoad = { await gate.wait() }

        async let first: Void = store.load(noteID: "note-1")
        while !store.isLoading { await Task.yield() }

        let finished = Flag()
        let second = Task { await store.load(noteID: "note-1"); finished.isOn = true }
        for _ in 0 ..< 20 { await Task.yield() }

        #expect(!finished.isOn)

        await gate.open()
        await first
        await second.value

        #expect(finished.isOn)
        #expect(repository.loadCallCount == 1)
        #expect(store.comments(for: "note-1").map(\.id) == ["a"])
    }

    /// 노트가 다르면 서로를 막지 않는다 — 겹침 방지는 같은 노트에 대해서만 건다.
    @Test("다른 노트의 로드는 서로를 기다리지 않는다")
    func loadsOfDifferentNotesDoNotBlockEachOther() async {
        let (store, repository) = store([comment("a", noteID: "note-1"), comment("b", noteID: "note-2")])
        let gate = Gate()
        repository.beforeLoad = { await gate.wait() }

        async let first: Void = store.load(noteID: "note-1")
        while !store.isLoading { await Task.yield() }
        async let second: Void = store.load(noteID: "note-2")
        for _ in 0 ..< 20 { await Task.yield() }

        await gate.open()
        _ = await (first, second)

        #expect(repository.loadCallCount == 2)
    }

    // MARK: - 개수 (뱃지)

    @Test("개수를 불러오면 노트별 뱃지 숫자가 채워진다")
    func loadsCounts() async {
        let (store, _) = store([
            comment("a", noteID: "note-1"),
            comment("b", noteID: "note-1", created: 10),
            comment("c", noteID: "note-2"),
        ])

        await store.loadCounts()

        #expect(store.count(for: "note-1") == 2)
        #expect(store.count(for: "note-2") == 1)
        // 댓글이 없는 노트는 0 — 화면은 0이면 뱃지를 그리지 않는다.
        #expect(store.count(for: "note-3") == 0)
    }

    @Test("개수 로드가 실패해도 이미 받아 둔 개수는 남는다")
    func failedCountsKeepPreviousNumbers() async {
        let (store, repository) = store([comment("a", noteID: "note-1")])
        await store.loadCounts()

        repository.loadError = NotesRepositoryError.network("끊김")
        await store.loadCounts()

        #expect(store.count(for: "note-1") == 1)
        #expect(store.errorMessage != nil)
    }

    @Test("개수 로드 취소는 오류가 아니다")
    func cancelledCountsLoadIsNotAFailure() async {
        let (store, repository) = store([comment("a", noteID: "note-1")])
        await store.loadCounts()

        repository.loadError = CancellationError()
        await store.loadCounts()

        #expect(store.errorMessage == nil)
        #expect(store.count(for: "note-1") == 1)
    }

    /// 목록을 열어 본 노트는 그 자리에서 개수가 맞춰져야 한다 —
    /// 뱃지와 실제 목록이 어긋나면 어느 쪽을 믿어야 할지 알 수 없다.
    @Test("목록을 불러오면 그 노트의 개수도 맞춰진다")
    func loadSyncsCount() async {
        let (store, _) = store([comment("a"), comment("b", created: 10)])

        await store.load(noteID: "note-1")

        #expect(store.count(for: "note-1") == 2)
    }

    // MARK: - 작성

    @Test("쓴 댓글이 목록 끝에 즉시 나타난다")
    func addAppendsImmediately() async {
        let (store, _) = store([comment("a")])
        await store.load(noteID: "note-1")

        await store.add(noteID: "note-1", body: "새 댓글")

        #expect(store.comments(for: "note-1").count == 2)
        #expect(store.comments(for: "note-1").last?.body == "새 댓글")
        #expect(store.count(for: "note-1") == 2)
    }

    @Test("작성이 실패하면 끼워 넣은 댓글을 되돌린다")
    func addRollsBackOnFailure() async {
        let (store, repository) = store([comment("a")])
        await store.load(noteID: "note-1")
        repository.createError = NotesRepositoryError.rejected("거절")

        await store.add(noteID: "note-1", body: "새 댓글")

        #expect(store.comments(for: "note-1").map(\.id) == ["a"])
        #expect(store.count(for: "note-1") == 1)
        #expect(store.errorMessage != nil)
    }

    /// DB가 `length(btrim(body)) > 0`을 요구한다. 서버까지 가서 거절당하지 말고
    /// 여기서 조용히 막는다 — 빈 입력은 오류가 아니라 아무 일도 아니다.
    @Test("공백뿐인 댓글은 보내지 않는다")
    func blankBodyIsNotSent() async {
        let (store, repository) = store()
        await store.load(noteID: "note-1")

        await store.add(noteID: "note-1", body: "   \n ")

        #expect(store.comments(for: "note-1").isEmpty)
        #expect(store.errorMessage == nil)
        #expect(repository.createCallCount == 0)
    }

    @Test("앞뒤 공백은 잘라서 보낸다")
    func trimsBodyBeforeSending() async {
        let (store, repository) = store()

        await store.add(noteID: "note-1", body: "  다듬어짐  ")

        #expect(repository.lastCreatedBody == "다듬어짐")
    }

    // MARK: - 삭제

    /// 댓글은 소프트 삭제가 없다 — 지우면 바로 사라진다.
    @Test("삭제하면 목록과 개수에서 함께 빠진다")
    func deleteRemovesFromListAndCount() async {
        let (store, _) = store([comment("a"), comment("b", created: 10)])
        await store.load(noteID: "note-1")

        await store.delete(id: "a", from: "note-1")

        #expect(store.comments(for: "note-1").map(\.id) == ["b"])
        #expect(store.count(for: "note-1") == 1)
    }

    @Test("삭제가 실패하면 댓글이 목록으로 돌아온다")
    func deleteRollsBackOnFailure() async {
        let (store, repository) = store([comment("a"), comment("b", created: 10)])
        await store.load(noteID: "note-1")
        repository.mutationError = NotesRepositoryError.network("끊김")

        await store.delete(id: "a", from: "note-1")

        #expect(store.comments(for: "note-1").map(\.id) == ["a", "b"])
        #expect(store.count(for: "note-1") == 2)
        #expect(store.errorMessage != nil)
    }

    @Test("오류는 확인하면 사라진다")
    func dismissesError() async {
        let (store, repository) = store()
        repository.loadError = NotesRepositoryError.network("끊김")
        await store.load(noteID: "note-1")

        store.dismissError()

        #expect(store.errorMessage == nil)
    }
}
