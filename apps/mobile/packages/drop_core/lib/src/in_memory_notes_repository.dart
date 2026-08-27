import 'note.dart';
import 'note_assembler.dart';
import 'notes_repository.dart';

var _idCounter = 0;

String _nextId() {
  _idCounter += 1;
  return '메모리-$_idCounter';
}

/// 테스트와 프리뷰용 리포지토리. 네트워크 없이 같은 계약을 지킨다.
/// DropCore `InMemoryNotesRepository.swift` 대응.
class InMemoryNotesRepository implements NotesRepository {
  final List<Note> _notes;

  /// 실패 경로를 시험하기 위한 손잡이.
  Object? loadError;
  Object? createError;
  Object? mutationError;

  /// `loadNotes`가 실제로 몇 번 불렸는지. 중복 로드를 세기 위한 것.
  int loadCallCount = 0;

  /// 로드를 원하는 시점까지 붙잡아 두기 위한 손잡이.
  /// 겹친 로드를 재현하려면 첫 로드를 여기서 멈춰 세워야 한다.
  Future<void> Function()? beforeLoad;

  /// 생성을 붙잡아 두기 위한 손잡이. 저장이 끝나기 **전** 화면 상태
  /// (낙관적으로 끼워 넣은 노트)를 보려면 여기서 멈춰 세워야 한다.
  Future<void> Function()? beforeCreate;

  InMemoryNotesRepository({List<Note> notes = const []}) : _notes = [...notes];

  @override
  Future<List<Note>> loadNotes() async {
    loadCallCount += 1;
    await beforeLoad?.call();
    final loadError = this.loadError;
    if (loadError != null) throw loadError;
    return NoteAssembler.sorted(_notes);
  }

  @override
  Future<Note> createNote({String content = '', String? parentId}) async {
    await beforeCreate?.call();
    final createError = this.createError;
    if (createError != null) throw createError;
    final note = Note(
      id: _nextId(),
      displayId: _notes.length + 1,
      content: content,
      parentId: parentId,
      createdAt: DateTime.now().toUtc(),
      updatedAt: DateTime.now().toUtc(),
      source: NoteSource.mobile,
    );
    _notes.insert(0, note);
    return note;
  }

  @override
  Future<void> updateNote({required String id, required String content}) =>
      _mutate(id, (note) => note.replacing(content: content));

  @override
  Future<void> moveToTrash(String id) => _mutate(
      id,
      (note) => note.replacing(
          archivedAt: null, deletedAt: DateTime.now().toUtc()));

  @override
  Future<void> restoreFromTrash(String id) =>
      _mutate(id, (note) => note.replacing(archivedAt: null, deletedAt: null));

  @override
  Future<void> archive(String id) => _mutate(
      id, (note) => note.replacing(archivedAt: DateTime.now().toUtc()));

  @override
  Future<void> unarchive(String id) =>
      _mutate(id, (note) => note.replacing(archivedAt: null));

  @override
  Future<void> deletePermanently(String id) async {
    final mutationError = this.mutationError;
    if (mutationError != null) throw mutationError;
    _notes.removeWhere((note) => note.id == id);
  }

  @override
  Future<void> emptyTrash() async {
    final mutationError = this.mutationError;
    if (mutationError != null) throw mutationError;
    _notes.removeWhere((note) => note.isInTrash);
  }

  @override
  Future<void> setPinned(String id, {required bool isPinned}) => _mutate(
      id,
      (note) => note.replacing(
          isPinned: isPinned,
          pinnedAt: isPinned ? DateTime.now().toUtc() : null));

  @override
  Future<void> setLocked(String id, {required bool isLocked}) =>
      _mutate(id, (note) => note.replacing(isLocked: isLocked));

  @override
  Future<void> setPriority(String id, int priority) =>
      _mutate(id, (note) => note.replacing(priority: priority.clamp(0, 3)));

  @override
  Future<void> updateCategories(
    String id, {
    required bool hasLink,
    required bool hasMedia,
    required bool hasFiles,
  }) =>
      _mutate(
          id,
          (note) => note.replacing(
              hasLink: hasLink, hasMedia: hasMedia, hasFiles: hasFiles));

  Future<void> _mutate(String id, Note Function(Note) transform) async {
    final mutationError = this.mutationError;
    if (mutationError != null) throw mutationError;
    final index = _notes.indexWhere((note) => note.id == id);
    if (index < 0) return;
    _notes[index] = transform(_notes[index]);
  }
}
