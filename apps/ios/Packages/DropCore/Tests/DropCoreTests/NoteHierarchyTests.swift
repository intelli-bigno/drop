import Foundation
import Testing

@testable import DropCore

/// 답글을 부모 아래로 묶는 순수 로직. 화면 없이 검증한다 (BRU-60).
@Suite("노트 계층")
struct NoteHierarchyTests {
    private func date(_ minute: Int) -> Date {
        Date(timeIntervalSince1970: 1_770_000_000 + TimeInterval(minute * 60))
    }

    private func note(
        _ id: String,
        parent: String? = nil,
        at minute: Int = 0,
        isPinned: Bool = false
    ) -> Note {
        Note(
            id: id,
            displayID: 0,
            content: id,
            parentID: parent,
            createdAt: date(minute),
            updatedAt: date(minute),
            source: .mobile,
            isPinned: isPinned
        )
    }

    /// 화면이 실제로 넘기는 순서 — 최신 노트가 위다.
    private func rows(_ notes: [Note], context: [Note]? = nil, maxIndentDepth: Int = 2) -> [NoteRow] {
        NoteHierarchy.rows(visible: notes, context: context ?? notes, maxIndentDepth: maxIndentDepth)
    }

    @Test("빈 목록은 행도 없다")
    func emptyProducesNoRows() {
        #expect(rows([]).isEmpty)
    }

    @Test("답글은 부모 바로 아래에 한 단 들여쓴다")
    func replySitsUnderItsParent() {
        let parent = note("부모", at: 10)
        let reply = note("답글", parent: "부모", at: 20)

        let result = rows([reply, parent])

        #expect(result.map(\.note.id) == ["부모", "답글"])
        #expect(result.map(\.depth) == [0, 1])
    }

    @Test("형제 답글은 오래된 것부터 (데스크톱과 같은 규칙)")
    func siblingsAreOldestFirst() {
        let result = rows([
            note("나중답글", parent: "부모", at: 30),
            note("먼저답글", parent: "부모", at: 20),
            note("부모", at: 10),
        ])

        #expect(result.map(\.note.id) == ["부모", "먼저답글", "나중답글"])
    }

    @Test("최상위 노트의 순서는 넘겨받은 순서를 그대로 지킨다")
    func rootOrderIsPreserved() {
        let result = rows([
            note("최신", at: 30),
            note("중간", at: 20),
            note("오래된", at: 10),
        ])

        #expect(result.map(\.note.id) == ["최신", "중간", "오래된"])
        #expect(result.allSatisfy { $0.depth == 0 })
    }

    @Test("손자까지 이어 붙인다 — 스레드가 통째로 붙어 있다")
    func threadStaysContiguous() {
        let result = rows([
            note("다른뿌리", at: 40),
            note("손자", parent: "답글", at: 30),
            note("답글", parent: "부모", at: 20),
            note("부모", at: 10),
        ])

        #expect(result.map(\.note.id) == ["다른뿌리", "부모", "답글", "손자"])
        #expect(result.map(\.depth) == [0, 0, 1, 2])
    }

    @Test("들여쓰기는 2단에서 멈춘다 — 좁은 화면에서 본문 폭이 무너지지 않게")
    func indentStopsAtLimit() {
        let result = rows([
            note("증손자", parent: "손자", at: 40),
            note("손자", parent: "답글", at: 30),
            note("답글", parent: "부모", at: 20),
            note("부모", at: 10),
        ])

        #expect(result.map(\.note.id) == ["부모", "답글", "손자", "증손자"])
        // 데이터상 깊이는 3이지만 들여쓰기는 2에서 멈춘다.
        #expect(result.map(\.depth) == [0, 1, 2, 2])
    }

    // MARK: - 필터·검색에서 부모가 빠졌을 때

    @Test("검색에 답글만 걸려도 부모를 끌어와 답글이 최상위로 튀지 않는다")
    func ancestorIsPulledInAsContext() {
        let parent = note("부모", at: 10)
        let reply = note("답글", parent: "부모", at: 20)

        // 검색어가 답글에만 걸린 상황
        let result = rows([reply], context: [parent, reply])

        #expect(result.map(\.note.id) == ["부모", "답글"])
        #expect(result.map(\.depth) == [0, 1])
        // 맥락으로 끌어온 부모는 그렇게 표시된다 — 검색 결과인 척하지 않는다.
        #expect(result.map(\.isContextOnly) == [true, false])
    }

    @Test("끌어온 부모가 또 답글이면 그 위까지 이어 올라간다")
    func ancestorChainIsPulledIn() {
        let result = rows(
            [note("손자", parent: "답글", at: 30)],
            context: [note("부모", at: 10), note("답글", parent: "부모", at: 20), note("손자", parent: "답글", at: 30)]
        )

        #expect(result.map(\.note.id) == ["부모", "답글", "손자"])
        #expect(result.map(\.isContextOnly) == [true, true, false])
    }

    @Test("부모가 다른 뷰에 있으면(보관·휴지통) 답글을 버리지 않고 최상위로 올리되 표시한다")
    func orphanIsPromotedAndMarked() {
        // 부모는 보관함에 있어 이 뷰의 context에 아예 없다.
        let orphan = note("답글", parent: "사라진부모", at: 20)

        let result = rows([orphan])

        #expect(result.map(\.note.id) == ["답글"])
        #expect(result.map(\.depth) == [0])
        // 독립 노트인 척하면 맥락이 사라진다 — 화면이 "답글"이라고 표시할 수 있게 알린다.
        #expect(result.map(\.isOrphanedReply) == [true])
    }

    @Test("맥락으로 끌어온 부모는 자기 자식 중 걸린 것만 데려온다")
    func contextParentDoesNotDragInUnmatchedSiblings() {
        let parent = note("부모", at: 10)
        let matched = note("걸린답글", parent: "부모", at: 20)
        let unmatched = note("안걸린답글", parent: "부모", at: 30)

        let result = rows([matched], context: [parent, matched, unmatched])

        #expect(result.map(\.note.id) == ["부모", "걸린답글"])
    }

    @Test("부모가 자기 자신을 가리키는 망가진 데이터에도 멈추지 않는다")
    func selfReferenceDoesNotLoop() {
        let result = rows([note("고리", parent: "고리", at: 10)])

        #expect(result.map(\.note.id) == ["고리"])
        #expect(result.map(\.depth) == [0])
    }

    @Test("두 노트가 서로를 가리켜도 멈추지 않는다")
    func mutualReferenceDoesNotLoop() {
        let result = rows([note("가", parent: "나", at: 10), note("나", parent: "가", at: 20)])

        #expect(Set(result.map(\.note.id)) == ["가", "나"])
    }

    @Test("같은 노트가 두 번 들어와도 행은 한 번만 난다")
    func duplicatesAreCollapsed() {
        let duplicated = note("부모", at: 10)

        let result = rows([duplicated, duplicated])

        #expect(result.map(\.note.id) == ["부모"])
    }
}
