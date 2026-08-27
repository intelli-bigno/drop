import 'comments_repository.dart';
import 'note_comment.dart';
import 'repository_error.dart';

var _placeholderCounter = 0;

/// 댓글 화면과 목록 뱃지가 함께 보는 상태. DropCore `CommentsStore.swift` 대응.
///
/// `NotesStore`와 **따로** 둔다 — 댓글은 노트가 아니고, 목록·검색·위젯이 보는
/// `visibleNotes`에 절대 섞이면 안 된다(BRU-62의 별도 테이블 설계를 상태에서도 지킨다).
///
/// 실패 규칙은 `NotesStore`와 같다(BRU-51):
/// 로드 실패는 보고 있던 목록을 지우지 않고, 취소는 오류가 아니며,
/// 겹친 로드는 새 요청을 보내지 않고 진행 중인 것이 끝날 때까지 기다린다.
class CommentsStore {
  /// 노트별 댓글 목록. 열어 본 노트만 들어 있다.
  final Map<String, List<NoteComment>> _commentsByNoteId = {};

  /// 노트별 댓글 수 — 목록 한 줄 행의 뱃지가 쓴다. 목록을 열지 않아도 채워진다.
  Map<String, int> _countsByNoteId = {};

  bool isLoading = false;
  String? errorMessage;

  final CommentsRepository _repository;

  /// 지금 도는 로드. 노트별로 하나씩 — 다른 노트의 로드는 서로를 막지 않는다.
  final Map<String, Future<void>> _inFlight = {};
  Future<void>? _countsInFlight;

  CommentsStore({required this._repository});

  List<NoteComment> commentsFor(String noteId) =>
      _commentsByNoteId[noteId] ?? const [];

  /// 뱃지 숫자. 모르는 노트는 0이고, 화면은 0이면 아무것도 그리지 않는다.
  int countFor(String noteId) => _countsByNoteId[noteId] ?? 0;

  // 로드

  Future<void> load(String noteId) {
    final existing = _inFlight[noteId];
    if (existing != null) return existing;

    final task = _performLoad(noteId).whenComplete(() {
      _inFlight.remove(noteId);
    });
    _inFlight[noteId] = task;
    return task;
  }

  /// 목록 화면이 뱃지를 채우기 위해 한 번 부른다.
  Future<void> loadCounts() {
    final existing = _countsInFlight;
    if (existing != null) return existing;

    final task = _performLoadCounts().whenComplete(() {
      _countsInFlight = null;
    });
    _countsInFlight = task;
    return task;
  }

  Future<void> _performLoad(String noteId) async {
    isLoading = true;
    errorMessage = null;
    try {
      final loaded = await _repository.loadComments(noteId);
      _commentsByNoteId[noteId] = [...loaded]
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      // 뱃지와 실제 목록이 어긋나면 어느 쪽을 믿어야 할지 알 수 없다.
      _countsByNoteId[noteId] = loaded.length;
    } catch (error) {
      if (isCancellationError(error)) {
        // 취소는 실패가 아니다. 보고 있던 목록을 그대로 둔다.
      } else {
        // 실패한 것은 "새 목록을 받아오는 일"이지 이미 받아 둔 목록이 아니다 (BRU-51).
        errorMessage = RepositoryErrorMessage.text(error);
      }
    }
    isLoading = false;
  }

  Future<void> _performLoadCounts() async {
    try {
      _countsByNoteId = await _repository.loadCommentCounts();
    } catch (error) {
      if (!isCancellationError(error)) {
        errorMessage = RepositoryErrorMessage.text(error);
      }
    }
  }

  // 작성 · 삭제

  /// 저장을 기다리지 않고 먼저 끼워 넣는다. 실패하면 걷어낸다 —
  /// 남겨 두면 저장되지도 않은 댓글이 화면에 남는다.
  Future<void> add({required String noteId, required String body}) async {
    final trimmed = body.trim();
    // DB가 `length(btrim(body)) > 0`을 요구한다. 서버까지 가서 거절당하는 대신
    // 여기서 조용히 막는다 — 빈 입력은 오류가 아니라 아무 일도 아니다.
    if (trimmed.isEmpty) return;

    _placeholderCounter += 1;
    final placeholder = NoteComment(
      id: '임시댓글-$_placeholderCounter',
      noteId: noteId,
      body: trimmed,
      createdAt: DateTime.now().toUtc(),
      updatedAt: DateTime.now().toUtc(),
    );
    _append(noteId, placeholder);

    try {
      final created =
          await _repository.createComment(noteId: noteId, body: trimmed);
      _replaceIn(noteId, placeholder.id, created);
    } catch (error) {
      _removeFrom(noteId, placeholder.id);
      errorMessage = RepositoryErrorMessage.text(error);
    }
  }

  /// 하드 삭제 — 댓글에는 휴지통이 없다.
  Future<void> delete({required String id, required String noteId}) async {
    final backup = commentsFor(noteId);
    _removeFrom(noteId, id);

    try {
      await _repository.deleteComment(id);
    } catch (error) {
      _commentsByNoteId[noteId] = backup;
      _countsByNoteId[noteId] = backup.length;
      errorMessage = RepositoryErrorMessage.text(error);
    }
  }

  void dismissError() {
    errorMessage = null;
  }

  // 내부

  void _append(String noteId, NoteComment comment) {
    final list = [...commentsFor(noteId), comment]
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    _commentsByNoteId[noteId] = list;
    _countsByNoteId[noteId] = list.length;
  }

  void _replaceIn(String noteId, String id, NoteComment comment) {
    final list = [...commentsFor(noteId)];
    final index = list.indexWhere((existing) => existing.id == id);
    if (index < 0) return;
    list[index] = comment;
    list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    _commentsByNoteId[noteId] = list;
  }

  void _removeFrom(String noteId, String id) {
    final list = commentsFor(noteId)
        .where((comment) => comment.id != id)
        .toList();
    _commentsByNoteId[noteId] = list;
    _countsByNoteId[noteId] = list.length;
  }
}
