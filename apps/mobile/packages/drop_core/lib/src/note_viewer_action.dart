import 'note.dart';

/// 노트 뷰어에서 고를 수 있는 동작 (BRU-77). DropCore `NoteViewerAction.swift` 대응.
///
/// 뷰어는 **읽기 전용 경로**다. 노트를 여는 것만으로는 아무것도 저장되지 않고,
/// 본문을 바꾸려면 `edit`으로 한 번 더 들어가야 한다 —
/// 데스크톱에서 "펼치기만 해도 원문이 덮어써지던" 사고(BRU-66)의 재발 방지다.
///
/// 어떤 동작이 가능한지는 노트의 상태가 정한다. 화면이 제 사정으로 버튼을 붙이면
/// 휴지통에 있는 노트에 "휴지통으로"가 붙는 식으로 어긋난다.
enum NoteViewerAction {
  edit,
  comments,
  archive,
  unarchive,
  trash,
  restore,
  deletePermanently;

  String get id => name;

  /// 이 동작이 노트 **본문**을 바꿀 수 있는가. 뷰어에서 본문을 건드리는 길은
  /// 편집기로 들어가는 `edit` 하나뿐이어야 한다.
  bool get writesContent => this == edit;

  static List<NoteViewerAction> actionsFor(Note note) {
    // 목록(`Note.matchesViewMode`)과 같은 순서로 가른다 — 휴지통이 보관보다 세다.
    if (note.isInTrash) {
      return const [comments, restore, deletePermanently];
    }
    if (note.isArchived) {
      return const [edit, comments, unarchive, trash];
    }
    return const [edit, comments, archive, trash];
  }
}
