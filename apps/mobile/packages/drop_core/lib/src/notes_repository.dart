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
  Future<void> updateCategories(
    String id, {
    required bool hasLink,
    required bool hasMedia,
    required bool hasFiles,
  });
}
