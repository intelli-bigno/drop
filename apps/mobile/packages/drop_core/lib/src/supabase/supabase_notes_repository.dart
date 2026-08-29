import '../attachment.dart';
import '../drop_json.dart';
import '../note.dart';
import '../note_assembler.dart';
import '../notes_repository.dart';
import '../repository_error.dart';
import '../tag.dart';
import 'insert_payloads.dart';
import 'supabase_rest.dart';

/// `notes` 테이블에 붙는 구현. DropCore `SupabaseNotesRepository.swift` 대응.
class SupabaseNotesRepository implements NotesRepository {
  final SupabaseRestClient client;

  SupabaseNotesRepository({required this.client});

  @override
  Future<List<Note>> loadNotes() async {
    final rows = await client.select('notes', {
      'select': '*',
      'order': 'created_at.desc',
    });
    final notes = await client.run(() async =>
        rows.map((row) => Note.fromJson((row as Map).cast())).toList());
    // 노트가 없으면 첨부·태그 쿼리를 아예 보내지 않는다.
    // 빈 `in` 필터는 PostgREST에서 오류이거나 전체 조회가 되어버린다.
    if (notes.isEmpty) return [];

    final ids = notes.map((note) => note.id).toList();
    final attachmentRows = await client.select('attachments', {
      'select': '*',
      'note_id': SupabaseRestClient.inFilter(ids),
      'order': 'created_at.asc',
    });
    final attachments = await client.run(() async => attachmentRows
        .map((row) => Attachment.fromJson((row as Map).cast()))
        .toList());
    final tagsByNoteId = await _loadTagsByNoteId(ids);

    return NoteAssembler.sorted(NoteAssembler.assemble(
      notes: notes,
      attachments: attachments,
      tagsByNoteId: tagsByNoteId,
    ));
  }

  @override
  Future<Note> createNote({String content = '', String? parentId}) async {
    // user_id를 반드시 실어 보낸다. INSERT 정책이 user_id = auth.uid()를 요구하는데
    // 컬럼에 기본값이 없어서, 빠뜨리면 NULL이 들어가 RLS가 거부한다.
    final userId = client.session.currentUserId;
    if (userId == null) throw const NotesRepositoryError.notAuthenticated();

    final row = await client.insertReturning(
      'notes',
      noteInsertPayload(content: content, parentId: parentId, userId: userId),
    );
    return client.run(() async => Note.fromJson(row));
  }

  @override
  Future<void> updateNote({required String id, required String content}) =>
      _update(id, {'content': content});

  @override
  Future<void> moveToTrash(String id) =>
      // Rule B (BRU-115): 복원은 받은편지함으로. 보관을 남기면 휴지통·보관함 양쪽에 나타난다.
      _update(id, {
        'is_deleted': true,
        'deleted_at': _now(),
        'archived_at': null,
      });

  @override
  Future<void> restoreFromTrash(String id) => _update(id, {
        'is_deleted': false,
        'deleted_at': null,
        'archived_at': null,
      });

  @override
  Future<void> archive(String id) => _update(id, {'archived_at': _now()});

  @override
  Future<void> unarchive(String id) => _update(id, {'archived_at': null});

  @override
  Future<void> deletePermanently(String id) =>
      client.delete('notes', filters: {'id': 'eq.$id'});

  @override
  Future<void> emptyTrash() async {
    final userId = client.session.currentUserId;
    if (userId == null) throw const NotesRepositoryError.notAuthenticated();
    await client.delete('notes', filters: {
      'user_id': 'eq.$userId',
      'deleted_at': 'not.is.null',
    });
  }

  @override
  Future<void> setPinned(String id, {required bool isPinned}) => _update(id, {
        'is_pinned': isPinned,
        'pinned_at': isPinned ? _now() : null,
      });

  @override
  Future<void> setLocked(String id, {required bool isLocked}) =>
      _update(id, {'is_locked': isLocked});

  @override
  Future<void> setPriority(String id, int priority) =>
      // DB CHECK 제약(0-3)에 걸리지 않도록 클라이언트에서 먼저 자른다.
      _update(id, {'priority': priority.clamp(0, 3)});

  @override
  Future<void> setType(String id, NoteType type) => _update(id, {
        'type': type.name,
        // 일반 노트로 되돌릴 때 완료 시각을 같은 갱신에서 지운다. 따로 두 번
        // 쓰면 그 사이 상태가 CHECK를 위반해 첫 갱신부터 거부된다 (BRU-184).
        if (type != NoteType.todo) 'completed_at': null,
      });

  @override
  Future<void> setCompleted(String id, {required bool completed}) => _update(
        id,
        {'completed_at': completed ? DateTime.now().toUtc().toIso8601String() : null},
      );

  @override
  Future<void> updateCategories(
    String id, {
    required bool hasLink,
    required bool hasMedia,
    required bool hasFiles,
  }) =>
      _update(id, {
        'has_link': hasLink,
        'has_media': hasMedia,
        'has_files': hasFiles,
      });

  // 내부

  Future<Map<String, List<Tag>>> _loadTagsByNoteId(List<String> noteIds) async {
    final rows = await client.select('note_tags', {
      'select': 'note_id, tags(*)',
      'note_id': SupabaseRestClient.inFilter(noteIds),
    });
    return client.run(() async {
      final result = <String, List<Tag>>{};
      for (final row in rows) {
        final map = (row as Map).cast<String, Object?>();
        final noteId = map['note_id'] as String;
        final tag = Tag.fromJson((map['tags'] as Map).cast());
        result.putIfAbsent(noteId, () => []).add(tag);
      }
      return result;
    });
  }

  Future<void> _update(String id, Map<String, Object?> values) =>
      client.update('notes', values, filters: {'id': 'eq.$id'});

  static String _now() => formatPostgresTimestamp(DateTime.now());
}
