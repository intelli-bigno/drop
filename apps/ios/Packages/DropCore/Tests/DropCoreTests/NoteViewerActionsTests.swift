import Foundation
import Testing

@testable import DropCore

/// 뷰어가 내놓는 액션 목록 (BRU-77).
///
/// "무엇을 할 수 있는가"는 노트의 상태가 정하는 규칙이지 화면의 사정이 아니다 —
/// 휴지통에 있는 노트에 "휴지통으로" 버튼이 붙는 식의 어긋남을 화면에서 잡을 방법이 없다.
@Suite("뷰어 액션")
struct NoteViewerActionsTests {
    private func note(archivedAt: Date? = nil, deletedAt: Date? = nil) -> Note {
        let now = Date()
        return Note(
            id: "n1", displayID: 1, content: "본문",
            createdAt: now, updatedAt: now, source: .mobile,
            archivedAt: archivedAt, deletedAt: deletedAt
        )
    }

    @Test("보통 노트에서는 편집·댓글·보관·휴지통")
    func activeNote() {
        #expect(NoteViewerAction.actions(for: note()) == [.edit, .comments, .archive, .trash])
    }

    @Test("보관한 노트에서는 보관 대신 보관 해제")
    func archivedNote() {
        let actions = NoteViewerAction.actions(for: note(archivedAt: Date()))
        #expect(actions == [.edit, .comments, .unarchive, .trash])
    }

    /// 휴지통에 있는 노트는 되살린 뒤에 고친다 — 지워진 것을 고치는 길을 만들면
    /// "지웠는데 왜 수정되나"가 된다.
    @Test("휴지통 노트는 복원·영구 삭제만, 편집은 없다")
    func trashedNote() {
        let actions = NoteViewerAction.actions(for: note(deletedAt: Date()))
        #expect(actions == [.comments, .restore, .deletePermanently])
        #expect(!actions.contains(.edit))
    }

    /// 보관과 휴지통에 동시에 걸린 노트는 휴지통이 이긴다 — 목록(`matches(viewMode:)`)이
    /// 이미 그렇게 가른다. 두 곳의 판정이 갈리면 안 보이는 노트에 엉뚱한 버튼이 붙는다.
    @Test("보관·휴지통이 겹치면 휴지통 규칙을 따른다")
    func trashWinsOverArchive() {
        let both = note(archivedAt: Date(), deletedAt: Date())
        #expect(NoteViewerAction.actions(for: both) == NoteViewerAction.actions(for: note(deletedAt: Date())))
    }

    /// 뷰어는 읽기 전용 경로다 (BRU-66 재발 방지). 저장은 편집기로 한 번 더 들어가야 한다.
    @Test("액션 목록만으로는 본문이 저장되지 않는다 — 저장은 편집을 거친다")
    func viewerHasNoImplicitSave() {
        for action in NoteViewerAction.actions(for: note()) {
            #expect(action.writesContent == (action == .edit))
        }
    }
}
