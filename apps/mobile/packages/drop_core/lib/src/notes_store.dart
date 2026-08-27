import 'note.dart';
import 'note_assembler.dart';
import 'note_hierarchy.dart';
import 'notes_repository.dart';
import 'repository_error.dart';
import 'tag.dart';

var _placeholderCounter = 0;

/// 홈 화면이 보는 상태 전부. DropCore `NotesStore.swift` 대응.
///
/// 목록은 보관·휴지통까지 통째로 받아 두고 화면에서 거른다 — 두 네이티브 앱과
/// 같은 구조라 목록이 어긋나지 않는다.
///
/// Swift 판의 `@Observable`은 플랫폼 몫이다 — Flutter 쪽에서 이 스토어를
/// 상태 관리(Riverpod 등)로 감싼다. 여기는 순수 상태 전이만 둔다.
class NotesStore {
  List<Note> allNotes = [];
  bool isLoading = false;
  String? errorMessage;

  NoteViewMode viewMode = NoteViewMode.active;
  NoteCategory category = NoteCategory.all;
  String? selectedTagId;
  String searchText = '';

  final Set<String> selectedIds = {};

  final NotesRepository _repository;

  /// 지금 도는 로드. 겹친 호출은 새 요청을 보내지 않고 이것을 기다린다.
  Future<void>? _inFlight;

  NotesStore({required this._repository});

  bool get isSelecting => selectedIds.isNotEmpty;

  /// 지금 탭(활성·보관·휴지통)과 카테고리에 속하는 노트 전부.
  /// 태그·검색으로 걸러지기 **전**이라, 답글의 부모를 맥락으로 끌어올 후보가 된다.
  List<Note> get scopedNotes => allNotes
      .where((note) =>
          note.matchesViewMode(viewMode) && note.matchesCategory(category))
      .toList();

  List<Note> get visibleNotes => scopedNotes.where((note) {
        final selectedTagId = this.selectedTagId;
        if (selectedTagId != null &&
            !note.tags.any((tag) => tag.id == selectedTagId)) {
          return false;
        }
        final query = searchText.trim();
        if (query.isNotEmpty &&
            !note.content.toLowerCase().contains(query.toLowerCase())) {
          return false;
        }
        return true;
      }).toList();

  /// 화면이 그리는 것. 답글이 부모 아래로 묶이고 들여쓰기 단수까지 정해져 있다.
  ///
  /// 부모는 **같은 탭 안에서만** 끌어온다 — 보관함에 있는 부모를 활성 목록에
  /// 끌어오면 지운 셈 친 노트가 되살아난다.
  List<NoteRow> get visibleRows =>
      NoteHierarchy.rows(visible: visibleNotes, context: scopedNotes);

  /// 지금 화면에 보이는 태그 목록 (필터 칩용).
  List<Tag> get availableTags {
    final seen = <String>{};
    return allNotes
        .expand((note) => note.tags)
        .where((tag) => seen.add(tag.id))
        .toList();
  }

  /// 목록을 다시 받아온다. 화면 진입과 당겨서 새로고침이 같은 입구를 쓴다.
  ///
  /// 겹친 호출은 요청을 한 번만 보내되, **먼저 도는 로드가 끝날 때까지 기다린다.**
  /// 즉시 돌려보내면 당겨서 새로고침은 스피너만 튕기고 아무 일도 하지 않은 것처럼
  /// 보인다 (BRU-51).
  Future<void> load() {
    final existing = _inFlight;
    if (existing != null) return existing;

    final task = _performLoad().whenComplete(() {
      _inFlight = null;
    });
    _inFlight = task;
    return task;
  }

  Future<void> _performLoad() async {
    isLoading = true;
    errorMessage = null;
    try {
      allNotes = await _repository.loadNotes();
    } catch (error) {
      if (isCancellationError(error)) {
        // 취소는 실패가 아니다. 보고 있던 목록을 그대로 둔다.
      } else {
        // 실패한 것은 "새 목록을 받아오는 일"이지 이미 받아 둔 목록이 아니다.
        // 여기서 목록을 비우면 당겨서 새로고침이 한 번 실패할 때마다 화면이
        // 통째로 사라진다 (BRU-51).
        errorMessage = RepositoryErrorMessage.text(error);
      }
    }
    isLoading = false;
  }

  /// [parentId]가 있으면 답글, 없으면 최상위 노트가 된다 (BRU-69).
  /// 돌려주는 이유는 첨부 때문이다 — 사진·카메라·공유함은 방금 만든 노트에
  /// 파일을 붙여야 하는데, 호출부가 목록에서 되찾으면 정렬 1순위가 `isPinned`라
  /// **고정 노트가 있는 순간 엉뚱한 노트에 붙는다**. 태그·검색 필터가 걸려 있으면
  /// 빈 노트는 `visibleNotes`에서 아예 걸러져 더 멀리 간다 (BRU-43).
  Future<Note?> create({required String content, String? parentId}) async {
    // 저장을 기다리지 않고 먼저 끼워 넣는다. 실패하면 걷어낸다 —
    // 남겨 두면 저장되지도 않은 노트가 목록에 남는다.
    //
    // parentId를 placeholder에도 실어야 한다. 빠뜨리면 답글이 최상위에 잠깐
    // 떴다가 저장이 끝나는 순간 부모 아래로 점프한다.
    _placeholderCounter += 1;
    final placeholder = Note(
      id: '임시-$_placeholderCounter',
      displayId: 0,
      content: content,
      parentId: parentId,
      createdAt: DateTime.now().toUtc(),
      updatedAt: DateTime.now().toUtc(),
      source: NoteSource.mobile,
    );
    allNotes = [placeholder, ...allNotes];

    try {
      final created =
          await _repository.createNote(content: content, parentId: parentId);
      _replace(placeholder.id, created);
      return created;
    } catch (error) {
      allNotes =
          allNotes.where((note) => note.id != placeholder.id).toList();
      errorMessage = RepositoryErrorMessage.text(error);
      return null;
    }
  }

  Future<void> update({required String id, required String content}) => _mutate(
        id,
        optimistic: (note) => note.replacing(
            content: content, updatedAt: DateTime.now().toUtc()),
        perform: () => _repository.updateNote(id: id, content: content),
      );

  Future<void> moveToTrash(String id) => _mutate(
        id,
        // Rule B (BRU-115): 복원은 받은편지함으로 되돌리기다. 보관을 남기면 보관함으로 간다.
        optimistic: (note) => note.replacing(
            archivedAt: null, deletedAt: DateTime.now().toUtc()),
        perform: () => _repository.moveToTrash(id),
      );

  Future<void> restore(String id) => _mutate(
        id,
        optimistic: (note) => note.replacing(archivedAt: null, deletedAt: null),
        perform: () => _repository.restoreFromTrash(id),
      );

  Future<void> archive(String id) => _mutate(
        id,
        optimistic: (note) =>
            note.replacing(archivedAt: DateTime.now().toUtc()),
        perform: () => _repository.archive(id),
      );

  Future<void> unarchive(String id) => _mutate(
        id,
        optimistic: (note) => note.replacing(archivedAt: null),
        perform: () => _repository.unarchive(id),
      );

  Future<void> setPinned(String id, {required bool isPinned}) => _mutate(
        id,
        optimistic: (note) => note.replacing(
            isPinned: isPinned,
            pinnedAt: isPinned ? DateTime.now().toUtc() : null),
        perform: () => _repository.setPinned(id, isPinned: isPinned),
      );

  Future<void> deletePermanently(String id) async {
    final backup = allNotes;
    allNotes = allNotes.where((note) => note.id != id).toList();
    try {
      await _repository.deletePermanently(id);
    } catch (error) {
      allNotes = backup;
      errorMessage = RepositoryErrorMessage.text(error);
    }
  }

  // 선택 모드

  void toggleSelection(String id) {
    if (!selectedIds.remove(id)) {
      selectedIds.add(id);
    }
  }

  void clearSelection() {
    selectedIds.clear();
  }

  void dismissError() {
    errorMessage = null;
  }

  /// 화면 쪽(첨부 업로드 등)에서 생긴 오류도 같은 자리에 보여 준다.
  void report(Object error) {
    errorMessage = RepositoryErrorMessage.text(error);
  }

  Future<void> trashSelected() async {
    final targets = [...selectedIds];
    // 일괄 처리 전에 선택을 비운다. 남겨 두면 다음 탭이 엉뚱한 노트에 걸린다.
    clearSelection();
    for (final id in targets) {
      await moveToTrash(id);
    }
  }

  Future<void> deleteSelectedPermanently() async {
    final targets = [...selectedIds];
    clearSelection();
    for (final id in targets) {
      await deletePermanently(id);
    }
  }

  // 내부

  Future<void> _mutate(
    String id, {
    required Note Function(Note) optimistic,
    required Future<void> Function() perform,
  }) async {
    final index = allNotes.indexWhere((note) => note.id == id);
    if (index < 0) return;
    final backup = allNotes[index];
    final updated = [...allNotes];
    updated[index] = optimistic(backup);
    allNotes = NoteAssembler.sorted(updated);

    try {
      await perform();
    } catch (error) {
      _replace(id, backup);
      errorMessage = RepositoryErrorMessage.text(error);
    }
  }

  void _replace(String id, Note note) {
    final index = allNotes.indexWhere((existing) => existing.id == id);
    if (index < 0) return;
    final updated = [...allNotes];
    updated[index] = note;
    allNotes = NoteAssembler.sorted(updated);
  }
}
