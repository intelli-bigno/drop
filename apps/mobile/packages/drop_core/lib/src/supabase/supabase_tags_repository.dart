import '../drop_json.dart';
import '../repository_error.dart';
import '../storage_path.dart';
import '../tag.dart';
import 'insert_payloads.dart';
import 'supabase_rest.dart';

/// DropCore `TagsRepository.swift` 대응.
class TagWithCount {
  final Tag tag;
  final int noteCount;
  final DateTime? lastUsedAt;

  String get id => tag.id;

  const TagWithCount({
    required this.tag,
    required this.noteCount,
    required this.lastUsedAt,
  });

  @override
  bool operator ==(Object other) =>
      other is TagWithCount &&
      other.tag == tag &&
      other.noteCount == noteCount &&
      other.lastUsedAt == lastUsedAt;

  @override
  int get hashCode => Object.hash(tag, noteCount, lastUsedAt);
}

abstract interface class TagsRepository {
  Future<List<TagWithCount>> loadTags();

  /// 이름이 같은 태그가 있으면 재사용하고, 없으면 만든다.
  Future<void> addTag({required String name, required String noteId});
  Future<void> removeTag({required String tagId, required String noteId});
  Future<void> renameTag({required String tagId, required String newName});
  Future<void> deleteTag(String tagId);
}

class SupabaseTagsRepository implements TagsRepository {
  final SupabaseRestClient client;

  SupabaseTagsRepository({required this.client});

  @override
  Future<List<TagWithCount>> loadTags() async {
    final rows = await client.select('tags', {
      'select': '*, note_tags(count)',
      'order': 'last_used_at.desc.nullslast',
    });
    return client.run(() async => rows.map((row) {
          final map = (row as Map).cast<String, Object?>();
          final countRows = map['note_tags'] as List<Object?>?;
          final firstCount = countRows == null || countRows.isEmpty
              ? 0
              : ((countRows.first as Map).cast<String, Object?>())['count']
                      as int? ??
                  0;
          return TagWithCount(
            tag: Tag.fromJson(map),
            noteCount: firstCount,
            lastUsedAt: parseOptionalPostgresTimestamp(map['last_used_at']),
          );
        }).toList());
  }

  @override
  Future<void> addTag({required String name, required String noteId}) async {
    // 공백뿐인 이름은 태그가 아니다. 대소문자·공백 차이로 같은 태그가
    // 둘로 갈라지지 않도록 정규화한 뒤 조회한다.
    final normalized = TagName.normalized(name);
    if (normalized == null) return;
    // notes와 같은 이유로 user_id를 직접 넣어야 한다 (기본값 없음 + RLS WITH CHECK).
    final userId = client.session.currentUserId;
    if (userId == null) throw const NotesRepositoryError.notAuthenticated();
    final now = DateTime.now().toUtc();

    final existingRows = await client.select('tags', {
      'select': '*',
      'name': 'eq.$normalized',
      'limit': '1',
    });

    String tagId;
    if (existingRows.isNotEmpty) {
      final existing = await client.run(() async =>
          Tag.fromJson((existingRows.first as Map).cast()));
      tagId = existing.id;
      await client.update(
        'tags',
        {'last_used_at': formatPostgresTimestamp(now)},
        filters: {'id': 'eq.${existing.id}'},
      );
    } else {
      final created = await client.insertReturning(
        'tags',
        tagInsertPayload(name: normalized, userId: userId, lastUsedAt: now),
      );
      tagId = await client.run(() async => Tag.fromJson(created).id);
    }

    // 이미 연결돼 있으면 조용히 넘어가야 한다 — 중복 연결은 오류가 아니다.
    await client.upsert('note_tags', {'note_id': noteId, 'tag_id': tagId});
  }

  @override
  Future<void> removeTag({required String tagId, required String noteId}) =>
      client.delete('note_tags', filters: {
        'note_id': 'eq.$noteId',
        'tag_id': 'eq.$tagId',
      });

  @override
  Future<void> renameTag(
      {required String tagId, required String newName}) async {
    final normalized = TagName.normalized(newName);
    if (normalized == null) return;
    await client.update(
      'tags',
      {'name': normalized},
      filters: {'id': 'eq.$tagId'},
    );
  }

  @override
  Future<void> deleteTag(String tagId) =>
      // note_tags는 CASCADE로 함께 지워진다.
      client.delete('tags', filters: {'id': 'eq.$tagId'});
}
