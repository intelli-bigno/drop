import 'package:drop_core/drop_core.dart';
import 'package:test/test.dart';

/// DropCore `NoteViewerActionsTests.swift` 포팅.
/// 뷰어가 내놓는 액션 목록 (BRU-77).
///
/// "무엇을 할 수 있는가"는 노트의 상태가 정하는 규칙이지 화면의 사정이 아니다 —
/// 휴지통에 있는 노트에 "휴지통으로" 버튼이 붙는 식의 어긋남을 화면에서 잡을 방법이 없다.
void main() {
  Note note({DateTime? archivedAt, DateTime? deletedAt}) {
    final now = DateTime.now();
    return Note(
      id: 'n1',
      displayId: 1,
      content: '본문',
      createdAt: now,
      updatedAt: now,
      source: NoteSource.mobile,
      archivedAt: archivedAt,
      deletedAt: deletedAt,
    );
  }

  group('뷰어 액션', () {
    test('보통 노트에서는 편집·댓글·보관·휴지통', () {
      expect(NoteViewerAction.actionsFor(note()), const [
        NoteViewerAction.edit,
        NoteViewerAction.comments,
        NoteViewerAction.archive,
        NoteViewerAction.trash,
      ]);
    });

    test('보관한 노트에서는 보관 대신 보관 해제', () {
      final actions = NoteViewerAction.actionsFor(note(archivedAt: DateTime.now()));
      expect(actions, const [
        NoteViewerAction.edit,
        NoteViewerAction.comments,
        NoteViewerAction.unarchive,
        NoteViewerAction.trash,
      ]);
    });

    /// 휴지통에 있는 노트는 되살린 뒤에 고친다 — 지워진 것을 고치는 길을 만들면
    /// "지웠는데 왜 수정되나"가 된다.
    test('휴지통 노트는 복원·영구 삭제만, 편집은 없다', () {
      final actions = NoteViewerAction.actionsFor(note(deletedAt: DateTime.now()));
      expect(actions, const [
        NoteViewerAction.comments,
        NoteViewerAction.restore,
        NoteViewerAction.deletePermanently,
      ]);
      expect(actions.contains(NoteViewerAction.edit), isFalse);
    });

    /// 보관과 휴지통에 동시에 걸린 노트는 휴지통이 이긴다 — 목록(`matchesViewMode`)이
    /// 이미 그렇게 가른다. 두 곳의 판정이 갈리면 안 보이는 노트에 엉뚱한 버튼이 붙는다.
    test('보관·휴지통이 겹치면 휴지통 규칙을 따른다', () {
      final both = note(archivedAt: DateTime.now(), deletedAt: DateTime.now());
      expect(
        NoteViewerAction.actionsFor(both),
        NoteViewerAction.actionsFor(note(deletedAt: DateTime.now())),
      );
    });

    /// 뷰어는 읽기 전용 경로다 (BRU-66 재발 방지). 저장은 편집기로 한 번 더 들어가야 한다.
    test('액션 목록만으로는 본문이 저장되지 않는다 — 저장은 편집을 거친다', () {
      for (final action in NoteViewerAction.actionsFor(note())) {
        expect(action.writesContent, action == NoteViewerAction.edit);
      }
    });
  });
}
