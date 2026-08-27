import 'dart:convert';

import 'package:drop_core/drop_core.dart';
import 'package:test/test.dart';

/// DropCore `NoteDecodingTests.swift` 포팅.
/// 실제 Supabase 응답 모양을 픽스처로 고정한다.
void main() {
  Note decode(String json) =>
      Note.fromJson(jsonDecode(json) as Map<String, Object?>);

  const fullRow = '''
  {
    "id": "6f1c1b2e-6a1e-4a1a-9a4e-0a1b2c3d4e5f",
    "display_id": 42,
    "content": "첫 노트",
    "parent_id": null,
    "created_at": "2026-08-11T09:30:00.123456+00:00",
    "updated_at": "2026-08-11T09:31:00+00:00",
    "source": "mobile",
    "is_deleted": false,
    "deleted_at": null,
    "archived_at": null,
    "has_link": false,
    "has_media": true,
    "has_files": false,
    "is_locked": false,
    "is_pinned": true,
    "pinned_at": "2026-08-11T10:00:00+00:00",
    "priority": 2
  }
  ''';

  group('Note 디코딩', () {
    test('전체 필드를 디코딩한다', () {
      final note = decode(fullRow);

      expect(note.id, '6f1c1b2e-6a1e-4a1a-9a4e-0a1b2c3d4e5f');
      expect(note.displayId, 42);
      expect(note.content, '첫 노트');
      expect(note.source, NoteSource.mobile);
      expect(note.hasMedia, isTrue);
      expect(note.isPinned, isTrue);
      expect(note.priority, 2);
      expect(note.pinnedAt, isNotNull);
    });

    /// Postgres timestamptz는 분수초가 붙기도 하고 안 붙기도 한다.
    test('분수초가 있든 없든 시각을 읽는다', () {
      final note = decode(fullRow);

      expect(note.createdAt, DateTime.parse('2026-08-11T09:30:00.123456Z'));
      expect(note.updatedAt, DateTime.parse('2026-08-11T09:31:00Z'));
    });

    /// content는 DB에서 null이 될 수 있는데 화면에서는 항상 문자열이어야 한다.
    test('content가 null이면 빈 문자열로 읽는다', () {
      final note =
          decode(fullRow.replaceFirst('"content": "첫 노트"', '"content": null'));
      expect(note.content, isEmpty);
    });

    /// #21에서 MCP로 만든 노트가 CHECK 제약에 걸린 이력이 있다.
    /// 서버가 아직 모르는 source 값을 보내도 목록 전체가 깨지면 안 된다.
    test('모르는 source 값이 와도 디코딩이 깨지지 않는다', () {
      final note = decode(
          fullRow.replaceFirst('"source": "mobile"', '"source": "watch"'));
      expect(note.source, NoteSource.unknown);
    });

    test('mcp source를 읽는다', () {
      final note =
          decode(fullRow.replaceFirst('"source": "mobile"', '"source": "mcp"'));
      expect(note.source, NoteSource.mcp);
    });

    /// 선택 컬럼이 응답에서 아예 빠져도(select 축소) 디코딩되어야 한다.
    test('선택 필드가 빠져도 기본값으로 채운다', () {
      const minimal = '''
      {
        "id": "abc",
        "display_id": 1,
        "created_at": "2026-08-11T09:30:00+00:00",
        "updated_at": "2026-08-11T09:30:00+00:00",
        "source": "desktop"
      }
      ''';
      final note = decode(minimal);

      expect(note.content, isEmpty);
      expect(note.isPinned, isFalse);
      expect(note.priority, 0);
      expect(note.tags, isEmpty);
      expect(note.attachments, isEmpty);
    });

    test('중첩된 태그·첨부를 함께 읽는다', () {
      const withRelations = '''
      {
        "id": "n1",
        "display_id": 7,
        "content": "본문",
        "created_at": "2026-08-11T09:30:00+00:00",
        "updated_at": "2026-08-11T09:30:00+00:00",
        "source": "web",
        "tags": [{"id": "t1", "name": "일", "created_at": "2026-08-01T00:00:00+00:00"}],
        "attachments": [{
          "id": "a1",
          "note_id": "n1",
          "type": "image",
          "storage_path": "u1/n1/a1.jpg",
          "filename": "a1.jpg",
          "mime_type": "image/jpeg",
          "size": 2048,
          "created_at": "2026-08-11T09:30:00+00:00"
        }]
      }
      ''';
      final note = decode(withRelations);

      expect(note.tags.map((t) => t.name), ['일']);
      expect(note.attachments.first.type, AttachmentType.image);
      expect(note.attachments.first.formattedSize, '2.0 KB');
    });
  });

  group('Note 상태 판정', () {
    Note note({
      DateTime? archivedAt,
      DateTime? deletedAt,
      bool hasLink = false,
    }) =>
        Note(
          id: 'n',
          displayId: 1,
          content: '',
          createdAt: DateTime.utc(1970),
          updatedAt: DateTime.utc(1970),
          source: NoteSource.mobile,
          archivedAt: archivedAt,
          deletedAt: deletedAt,
          hasLink: hasLink,
        );

    test('보관·휴지통이 아니면 활성이다', () {
      expect(note().matchesViewMode(NoteViewMode.active), isTrue);
      expect(note().matchesViewMode(NoteViewMode.archived), isFalse);
      expect(note().matchesViewMode(NoteViewMode.trash), isFalse);
    });

    test('보관된 노트는 활성이 아니다', () {
      final archived = note(archivedAt: DateTime.now());
      expect(archived.matchesViewMode(NoteViewMode.archived), isTrue);
      expect(archived.matchesViewMode(NoteViewMode.active), isFalse);
    });

    test('휴지통 노트는 활성이 아니다', () {
      final trashed = note(deletedAt: DateTime.now());
      expect(trashed.matchesViewMode(NoteViewMode.trash), isTrue);
      expect(trashed.matchesViewMode(NoteViewMode.active), isFalse);
    });

    test('카테고리 필터는 플래그를 본다', () {
      expect(note(hasLink: true).matchesCategory(NoteCategory.links), isTrue);
      expect(note().matchesCategory(NoteCategory.links), isFalse);
      expect(note().matchesCategory(NoteCategory.all), isTrue);
    });
  });
}
