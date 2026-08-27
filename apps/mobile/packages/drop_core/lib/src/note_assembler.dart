import 'attachment.dart';
import 'note.dart';
import 'tag.dart';

/// 목록 조회 결과(노트 / 첨부 / 태그)를 화면이 쓰는 형태로 합친다.
/// 순수 함수로 떼어 두어 네트워크 없이 검증한다. DropCore `NoteAssembler.swift` 대응.
class NoteAssembler {
  NoteAssembler._();

  static List<Note> assemble({
    required List<Note> notes,
    required List<Attachment> attachments,
    required Map<String, List<Tag>> tagsByNoteId,
  }) {
    // 주인 없는 첨부(삭제된 노트의 잔여물 등)는 여기서 자연스럽게 버려진다.
    final attachmentsByNoteId = <String, List<Attachment>>{};
    for (final attachment in attachments) {
      attachmentsByNoteId.putIfAbsent(attachment.noteId, () => []).add(attachment);
    }

    return notes
        .map((note) => note.replacing(
              attachments: attachmentsByNoteId[note.id] ?? const [],
              tags: tagsByNoteId[note.id] ?? const [],
            ))
        .toList();
  }

  /// 고정 먼저 → 고정 시각 최신순 → 생성 시각 최신순.
  /// 서버 정렬과 같은 규칙을 클라이언트에도 두어, 낙관적 갱신으로 끼워 넣은
  /// 노트가 새로고침 전후로 자리를 바꾸지 않게 한다.
  static List<Note> sorted(List<Note> notes) {
    final copy = [...notes];
    copy.sort((lhs, rhs) {
      if (lhs.isPinned != rhs.isPinned) return lhs.isPinned ? -1 : 1;
      if (lhs.isPinned && rhs.isPinned) {
        final lhsPinned = lhs.pinnedAt ?? DateTime.utc(0);
        final rhsPinned = rhs.pinnedAt ?? DateTime.utc(0);
        if (!lhsPinned.isAtSameMomentAs(rhsPinned)) {
          return rhsPinned.compareTo(lhsPinned);
        }
      }
      return rhs.createdAt.compareTo(lhs.createdAt);
    });
    return copy;
  }
}
