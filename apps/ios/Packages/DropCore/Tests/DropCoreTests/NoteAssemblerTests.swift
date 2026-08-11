import Foundation
import Testing

@testable import DropCore

/// 목록 조회는 notes / attachments / note_tags 세 번의 쿼리 결과를 합쳐 만든다.
/// 합치는 규칙만 떼어내면 네트워크 없이 검증할 수 있다 — 실제 버그가 나는 곳도 여기다.
@Suite("노트 조립")
struct NoteAssemblerTests {
    private let now = Date(timeIntervalSince1970: 1_770_000_000)

    private func note(_ id: String, pinned: Bool = false, pinnedAt: Date? = nil, created: TimeInterval = 0) -> Note {
        Note(
            id: id, displayID: 1, content: "", createdAt: now.addingTimeInterval(created),
            updatedAt: now, source: .mobile, isPinned: pinned, pinnedAt: pinnedAt
        )
    }

    private func attachment(_ id: String, noteID: String) -> DropCore.Attachment {
        DropCore.Attachment(id: id, noteID: noteID, type: .image, storagePath: "p/\(id)", createdAt: now)
    }

    private func tag(_ id: String, _ name: String) -> DropCore.Tag {
        DropCore.Tag(id: id, name: name, createdAt: now)
    }

    @Test("첨부와 태그를 노트별로 붙인다")
    func attachesRelationsToOwners() {
        let assembled = NoteAssembler.assemble(
            notes: [note("n1"), note("n2")],
            attachments: [attachment("a1", noteID: "n1"), attachment("a2", noteID: "n1")],
            tagsByNoteID: ["n2": [tag("t1", "일")]]
        )

        #expect(assembled[0].attachments.map(\.id) == ["a1", "a2"])
        #expect(assembled[0].tags.isEmpty)
        #expect(assembled[1].attachments.isEmpty)
        #expect(assembled[1].tags.map(\.name) == ["일"])
    }

    /// 삭제된 노트의 첨부가 뒤늦게 딸려오는 경우가 있다. 주인 없는 첨부는 버린다.
    @Test("주인이 없는 첨부는 버린다")
    func dropsOrphanAttachments() {
        let assembled = NoteAssembler.assemble(
            notes: [note("n1")],
            attachments: [attachment("a1", noteID: "n1"), attachment("a9", noteID: "없는노트")],
            tagsByNoteID: [:]
        )

        #expect(assembled.count == 1)
        #expect(assembled[0].attachments.map(\.id) == ["a1"])
    }

    @Test("입력 순서를 그대로 유지한다")
    func preservesInputOrder() {
        let assembled = NoteAssembler.assemble(
            notes: [note("c"), note("a"), note("b")],
            attachments: [],
            tagsByNoteID: [:]
        )

        #expect(assembled.map(\.id) == ["c", "a", "b"])
    }

    /// 정렬 규칙: 고정 먼저 → 고정 시각 최신순 → 생성 시각 최신순.
    /// Flutter가 서버 정렬(order 3개)에 의존하던 것을 클라이언트에서도 같은 규칙으로 맞춘다.
    @Test("고정된 노트가 위로, 그 안에서는 최신순")
    func sortsPinnedFirstThenNewest() {
        let old = note("old", created: -100)
        let new = note("new", created: 100)
        let pinnedEarlier = note("p1", pinned: true, pinnedAt: now.addingTimeInterval(-50))
        let pinnedLater = note("p2", pinned: true, pinnedAt: now)

        let sorted = NoteAssembler.sorted([old, new, pinnedEarlier, pinnedLater])

        #expect(sorted.map(\.id) == ["p2", "p1", "new", "old"])
    }

    /// 고정 시각이 없는 오래된 데이터가 섞여 있어도 정렬이 무너지면 안 된다.
    @Test("고정 시각이 없는 고정 노트도 고정 묶음에 남는다")
    func pinnedWithoutTimestampStaysPinned() {
        let pinnedNoDate = note("p0", pinned: true, pinnedAt: nil)
        let plain = note("n", created: 1000)

        let sorted = NoteAssembler.sorted([plain, pinnedNoDate])

        #expect(sorted.map(\.id) == ["p0", "n"])
    }
}
