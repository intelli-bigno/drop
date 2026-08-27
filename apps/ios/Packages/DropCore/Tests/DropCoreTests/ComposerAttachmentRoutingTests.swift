import Foundation
import Testing

@testable import DropCore

/// 컴포저에서 고른 미디어가 어느 노트에 붙는지 (BRU-131).
///
/// 홈 PhotosPicker는 빈 노트를 새로 만들고 붙인다. 편집 시트는 지금 고치고
/// 있는 그 노트에 붙여야 한다 — 새 display_id가 생기면 안 된다.
@Suite("컴포저 첨부 경로")
struct ComposerAttachmentRoutingTests {
    @Test("편집 중인 노트 id가 있으면 그 노트에 붙인다")
    func existingNoteKeepsItsID() {
        let destination = ComposerAttachmentRouting.destination(editingNoteID: "existing-1")
        #expect(destination == .existing(noteID: "existing-1"))
        #expect(
            ComposerAttachmentRouting.noteIDToAttach(
                destination: destination,
                createdNoteID: "new-2"
            ) == "existing-1"
        )
    }

    @Test("새 노트는 만든 뒤에 그 id로 붙인다")
    func newNoteAttachesAfterCreate() {
        let destination = ComposerAttachmentRouting.destination(editingNoteID: nil)
        #expect(destination == .createThenAttach)
        #expect(
            ComposerAttachmentRouting.noteIDToAttach(
                destination: destination,
                createdNoteID: nil
            ) == nil
        )
        #expect(
            ComposerAttachmentRouting.noteIDToAttach(
                destination: destination,
                createdNoteID: "created-1"
            ) == "created-1"
        )
    }

    @Test("기존 노트 경로는 새로 만든 id를 쓰지 않는다")
    func existingPathIsSeparateFromCreate() {
        let existing = ComposerAttachmentRouting.destination(editingNoteID: "keep-me")
        let created = ComposerAttachmentRouting.destination(editingNoteID: nil)

        #expect(existing != created)
        #expect(
            ComposerAttachmentRouting.noteIDToAttach(
                destination: existing,
                createdNoteID: "must-not-use"
            ) != "must-not-use"
        )
    }
}
