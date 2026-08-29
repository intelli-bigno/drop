import 'note.dart';

/// 노트 데이터 접근 경계. 화면은 이 인터페이스만 알고, 테스트는 인메모리 구현을 쓴다.
/// DropCore `NotesRepository.swift` 대응.
abstract interface class NotesRepository {
  /// 목록 전체를 한 번에 가져온다. 보관·휴지통까지 포함해 받고 화면에서 거른다 —
  /// 두 네이티브 앱과 같은 방식이라 목록이 어긋나지 않는다.
  Future<List<Note>> loadNotes();

  Future<Note> createNote({String content = '', String? parentId});
  Future<void> updateNote({required String id, required String content});

  /// 휴지통으로 보낸다(soft delete). 보관 상태였다면 함께 해제한다.
  Future<void> moveToTrash(String id);
  Future<void> restoreFromTrash(String id);
  Future<void> archive(String id);
  Future<void> unarchive(String id);
  Future<void> deletePermanently(String id);
  Future<void> emptyTrash();

  Future<void> setPinned(String id, {required bool isPinned});
  Future<void> setLocked(String id, {required bool isLocked});
  Future<void> setPriority(String id, int priority);

  /// 노트의 종류를 바꾼다 (BRU-184).
  ///
  /// 일반 노트로 되돌릴 때는 `completedAt`도 함께 지워야 한다 — DB
  /// CHECK(`notes_todo_state_consistent`)가 완료 시각이 남은 일반 노트를
  /// 거부하므로, 두 컬럼을 한 번에 쓰지 않으면 갱신 자체가 실패한다.
  Future<void> setType(String id, NoteType type);

  /// 할일의 완료를 표시하거나 해제한다 (BRU-184).
  Future<void> setCompleted(String id, {required bool completed});
  Future<void> updateCategories(
    String id, {
    required bool hasLink,
    required bool hasMedia,
    required bool hasFiles,
  });
}
