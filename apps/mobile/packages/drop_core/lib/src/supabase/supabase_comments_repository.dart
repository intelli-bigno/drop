import '../comments_repository.dart';
import '../note_comment.dart';
import '../repository_error.dart';
import 'insert_payloads.dart';
import 'supabase_rest.dart';

/// `note_comments` 테이블에 붙는 구현. RLS가 "자기가 쓴, 자기 노트의 댓글"만
/// 통과시키므로 쿼리에 사용자 조건을 다시 적지 않는다.
/// DropCore `SupabaseCommentsRepository.swift` 대응.
class SupabaseCommentsRepository implements CommentsRepository {
  final SupabaseRestClient client;

  SupabaseCommentsRepository({required this.client});

  @override
  Future<List<NoteComment>> loadComments(String noteId) async {
    final rows = await client.select('note_comments', {
      'select': '*',
      'note_id': 'eq.$noteId',
      'order': 'created_at.asc',
    });
    return client.run(() async =>
        rows.map((row) => NoteComment.fromJson((row as Map).cast())).toList());
  }

  @override
  Future<Map<String, int>> loadCommentCounts() async {
    // note_id만 받아 클라이언트에서 센다. 집계 함수를 쓰려면 뷰나 RPC가 필요한데,
    // 댓글 수는 개인 노트 규모에서 수백 행을 넘지 않는다.
    final rows = await client.select('note_comments', {'select': 'note_id'});
    return client.run(() async {
      final counts = <String, int>{};
      for (final row in rows) {
        final noteId = ((row as Map).cast<String, Object?>())['note_id'] as String;
        counts[noteId] = (counts[noteId] ?? 0) + 1;
      }
      return counts;
    });
  }

  @override
  Future<NoteComment> createComment({
    required String noteId,
    required String body,
  }) async {
    // notes와 같은 이유로 user_id를 직접 넣는다 — 컬럼에 기본값이 없고
    // INSERT 정책이 user_id = auth.uid()를 요구한다.
    final userId = client.session.currentUserId;
    if (userId == null) throw const NotesRepositoryError.notAuthenticated();

    final row = await client.insertReturning(
      'note_comments',
      commentInsertPayload(noteId: noteId, userId: userId, body: body),
    );
    return client.run(() async => NoteComment.fromJson(row));
  }

  @override
  Future<void> deleteComment(String id) =>
      client.delete('note_comments', filters: {'id': 'eq.$id'});
}
