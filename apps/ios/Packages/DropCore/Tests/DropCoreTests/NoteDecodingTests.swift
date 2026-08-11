import Foundation
import Testing

@testable import DropCore

/// 실제 Supabase 응답 모양을 픽스처로 고정한다.
/// Flutter 쪽 `NoteRow`가 받던 것과 같은 JSON이어야 한다.
@Suite("Note 디코딩")
struct NoteDecodingTests {
    private func decode(_ json: String) throws -> Note {
        try DropJSON.decoder.decode(Note.self, from: Data(json.utf8))
    }

    private let fullRow = """
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
    """

    @Test("전체 필드를 디코딩한다")
    func decodesFullRow() throws {
        let note = try decode(fullRow)

        #expect(note.id == "6f1c1b2e-6a1e-4a1a-9a4e-0a1b2c3d4e5f")
        #expect(note.displayID == 42)
        #expect(note.content == "첫 노트")
        #expect(note.source == .mobile)
        #expect(note.hasMedia)
        #expect(note.isPinned)
        #expect(note.priority == 2)
        #expect(note.pinnedAt != nil)
    }

    /// Postgres timestamptz는 분수초가 붙기도 하고 안 붙기도 한다.
    /// 기본 ISO8601 디코딩 전략은 분수초가 붙은 쪽에서 실패한다.
    @Test("분수초가 있든 없든 시각을 읽는다")
    func decodesBothTimestampShapes() throws {
        let note = try decode(fullRow)

        let created = ISO8601DateFormatter()
        created.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        #expect(note.createdAt == created.date(from: "2026-08-11T09:30:00.123456Z"))

        let updated = ISO8601DateFormatter()
        updated.formatOptions = [.withInternetDateTime]
        #expect(note.updatedAt == updated.date(from: "2026-08-11T09:31:00Z"))
    }

    /// content는 DB에서 null이 될 수 있는데 화면에서는 항상 문자열이어야 한다.
    @Test("content가 null이면 빈 문자열로 읽는다")
    func nullContentBecomesEmpty() throws {
        let note = try decode(fullRow.replacingOccurrences(of: "\"content\": \"첫 노트\"", with: "\"content\": null"))
        #expect(note.content.isEmpty)
    }

    /// #21에서 MCP로 만든 노트가 CHECK 제약에 걸린 이력이 있다.
    /// 서버가 아직 모르는 source 값을 보내도 목록 전체가 깨지면 안 된다.
    @Test("모르는 source 값이 와도 디코딩이 깨지지 않는다")
    func unknownSourceDoesNotBreakDecoding() throws {
        let note = try decode(fullRow.replacingOccurrences(of: "\"source\": \"mobile\"", with: "\"source\": \"watch\""))
        #expect(note.source == .unknown)
    }

    @Test("mcp source를 읽는다")
    func decodesMCPSource() throws {
        let note = try decode(fullRow.replacingOccurrences(of: "\"source\": \"mobile\"", with: "\"source\": \"mcp\""))
        #expect(note.source == .mcp)
    }

    /// 선택 컬럼이 응답에서 아예 빠져도(select 축소) 디코딩되어야 한다.
    @Test("선택 필드가 빠져도 기본값으로 채운다")
    func missingOptionalFieldsUseDefaults() throws {
        let minimal = """
        {
          "id": "abc",
          "display_id": 1,
          "created_at": "2026-08-11T09:30:00+00:00",
          "updated_at": "2026-08-11T09:30:00+00:00",
          "source": "desktop"
        }
        """
        let note = try decode(minimal)

        #expect(note.content.isEmpty)
        #expect(!note.isPinned)
        #expect(note.priority == 0)
        #expect(note.tags.isEmpty)
        #expect(note.attachments.isEmpty)
    }

    @Test("중첩된 태그·첨부를 함께 읽는다")
    func decodesNestedRelations() throws {
        let withRelations = """
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
        """
        let note = try decode(withRelations)

        #expect(note.tags.map(\.name) == ["일"])
        #expect(note.attachments.first?.type == .image)
        #expect(note.attachments.first?.formattedSize == "2.0 KB")
    }
}

@Suite("Note 상태 판정")
struct NoteStateTests {
    private func note(archivedAt: Date? = nil, deletedAt: Date? = nil, hasLink: Bool = false) -> Note {
        Note(
            id: "n", displayID: 1, content: "", parentID: nil,
            createdAt: .distantPast, updatedAt: .distantPast, source: .mobile,
            archivedAt: archivedAt, deletedAt: deletedAt,
            hasLink: hasLink
        )
    }

    @Test("보관·휴지통이 아니면 활성이다")
    func activeWhenNeitherArchivedNorDeleted() {
        #expect(note().matches(viewMode: .active))
        #expect(!note().matches(viewMode: .archived))
        #expect(!note().matches(viewMode: .trash))
    }

    @Test("보관된 노트는 활성이 아니다")
    func archivedIsNotActive() {
        let archived = note(archivedAt: .now)
        #expect(archived.matches(viewMode: .archived))
        #expect(!archived.matches(viewMode: .active))
    }

    @Test("휴지통 노트는 활성이 아니다")
    func trashedIsNotActive() {
        let trashed = note(deletedAt: .now)
        #expect(trashed.matches(viewMode: .trash))
        #expect(!trashed.matches(viewMode: .active))
    }

    @Test("카테고리 필터는 플래그를 본다")
    func categoryFiltersOnFlags() {
        #expect(note(hasLink: true).matches(category: .links))
        #expect(!note().matches(category: .links))
        #expect(note().matches(category: .all))
    }
}
