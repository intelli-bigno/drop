import 'comments_repository.dart';
import 'note_comment.dart';

var _idCounter = 0;

String _nextId() {
  _idCounter += 1;
  return '메모리댓글-$_idCounter';
}

/// 테스트와 프리뷰용 리포지토리. 네트워크 없이 같은 계약을 지킨다.
/// DropCore `InMemoryCommentsRepository.swift` 대응.
class InMemoryCommentsRepository implements CommentsRepository {
  final List<NoteComment> _comments;

  /// 실패 경로를 시험하기 위한 손잡이.
  Object? loadError;
  Object? createError;
  Object? mutationError;

  /// 로드를 원하는 시점까지 붙잡아 두기 위한 손잡이 — 겹친 로드를 재현한다.
  Future<void> Function()? beforeLoad;

  int loadCallCount = 0;
  int createCallCount = 0;

  /// 다듬기(trim)가 실제로 걸렸는지 보기 위한 것.
  String? lastCreatedBody;

  InMemoryCommentsRepository({List<NoteComment> comments = const []})
      : _comments = [...comments];

  @override
  Future<List<NoteComment>> loadComments(String noteId) async {
    loadCallCount += 1;
    await beforeLoad?.call();
    final loadError = this.loadError;
    if (loadError != null) throw loadError;
    return _comments.where((comment) => comment.noteId == noteId).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  @override
  Future<Map<String, int>> loadCommentCounts() async {
    final loadError = this.loadError;
    if (loadError != null) throw loadError;
    final counts = <String, int>{};
    for (final comment in _comments) {
      counts[comment.noteId] = (counts[comment.noteId] ?? 0) + 1;
    }
    return counts;
  }

  @override
  Future<NoteComment> createComment({
    required String noteId,
    required String body,
  }) async {
    createCallCount += 1;
    lastCreatedBody = body;
    final createError = this.createError;
    if (createError != null) throw createError;
    final comment = NoteComment(
      id: _nextId(),
      noteId: noteId,
      body: body,
      createdAt: DateTime.now().toUtc(),
      updatedAt: DateTime.now().toUtc(),
    );
    _comments.add(comment);
    return comment;
  }

  @override
  Future<void> deleteComment(String id) async {
    final mutationError = this.mutationError;
    if (mutationError != null) throw mutationError;
    _comments.removeWhere((comment) => comment.id == id);
  }
}
