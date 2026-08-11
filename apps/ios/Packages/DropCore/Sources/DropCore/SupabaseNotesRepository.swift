import Foundation
import Supabase

/// `notes_repository.dart`의 Supabase 구현을 옮긴 것.
public struct SupabaseNotesRepository: NotesRepository {
    private let client: SupabaseClient

    public init(client: SupabaseClient) {
        self.client = client
    }

    public func loadNotes() async throws -> [Note] {
        let notes: [Note] = try await run {
            try await client.from("notes").select().order("created_at", ascending: false).execute().value
        }
        guard !notes.isEmpty else { return [] }

        let ids = notes.map(\.id)
        let attachments: [Attachment] = try await run {
            try await client.from("attachments")
                .select()
                .in("note_id", values: ids)
                .order("created_at")
                .execute().value
        }
        let tagsByNoteID = try await loadTagsByNoteID(noteIDs: ids)

        return NoteAssembler.sorted(
            NoteAssembler.assemble(notes: notes, attachments: attachments, tagsByNoteID: tagsByNoteID)
        )
    }

    public func createNote(content: String, parentID: String?) async throws -> Note {
        // user_id는 클라이언트가 넣지 않는다 — RLS 정책과 DB 기본값이 정한다.
        guard client.auth.currentUser != nil else { throw NotesRepositoryError.notAuthenticated }

        return try await run {
            try await client.from("notes")
                .insert(NoteInsert(content: content, parentId: parentID, source: "mobile"))
                .select()
                .single()
                .execute().value
        }
    }

    public func updateNote(id: String, content: String) async throws {
        try await update(id: id, values: ["content": .string(content)])
    }

    public func moveToTrash(id: String) async throws {
        // 보관 해제를 함께 하지 않으면 휴지통과 보관함 양쪽에 나타난다.
        try await update(id: id, values: [
            "is_deleted": .bool(true),
            "deleted_at": .string(nowTimestamp()),
            "archived_at": .null,
        ])
    }

    public func restoreFromTrash(id: String) async throws {
        try await update(id: id, values: ["is_deleted": .bool(false), "deleted_at": .null])
    }

    public func archive(id: String) async throws {
        try await update(id: id, values: ["archived_at": .string(nowTimestamp())])
    }

    public func unarchive(id: String) async throws {
        try await update(id: id, values: ["archived_at": .null])
    }

    public func deletePermanently(id: String) async throws {
        _ = try await run { try await client.from("notes").delete().eq("id", value: id).execute() }
    }

    public func emptyTrash() async throws {
        guard let user = client.auth.currentUser else { throw NotesRepositoryError.notAuthenticated }
        _ = try await run {
            try await client.from("notes")
                .delete()
                .eq("user_id", value: user.id.uuidString)
                .not("deleted_at", operator: .is, value: AnyJSON.null)
                .execute()
        }
    }

    public func setPinned(id: String, isPinned: Bool) async throws {
        try await update(id: id, values: [
            "is_pinned": .bool(isPinned),
            "pinned_at": isPinned ? .string(nowTimestamp()) : .null,
        ])
    }

    public func setLocked(id: String, isLocked: Bool) async throws {
        try await update(id: id, values: ["is_locked": .bool(isLocked)])
    }

    public func setPriority(id: String, priority: Int) async throws {
        // DB CHECK 제약(0-3)에 걸리지 않도록 클라이언트에서 먼저 자른다.
        try await update(id: id, values: ["priority": .integer(min(max(priority, 0), 3))])
    }

    public func updateCategories(id: String, hasLink: Bool, hasMedia: Bool, hasFiles: Bool) async throws {
        try await update(id: id, values: [
            "has_link": .bool(hasLink),
            "has_media": .bool(hasMedia),
            "has_files": .bool(hasFiles),
        ])
    }

    // MARK: - 내부

    private func loadTagsByNoteID(noteIDs: [String]) async throws -> [String: [Tag]] {
        let rows: [NoteTagRow] = try await run {
            try await client.from("note_tags")
                .select("note_id, tags(*)")
                .in("note_id", values: noteIDs)
                .execute().value
        }
        return rows.reduce(into: [:]) { result, row in
            result[row.noteID, default: []].append(row.tag)
        }
    }

    private func update(id: String, values: [String: AnyJSON]) async throws {
        _ = try await run { try await client.from("notes").update(values).eq("id", value: id).execute() }
    }

    private func nowTimestamp() -> String {
        ISO8601DateFormatter().string(from: Date())
    }

    /// Supabase/PostgREST 오류를 화면이 다룰 수 있는 형태로 좁힌다.
    private func run<T>(_ operation: () async throws -> T) async throws -> T {
        do {
            return try await operation()
        } catch let error as PostgrestError {
            throw NotesRepositoryError.rejected(error.message)
        } catch let error as DecodingError {
            throw NotesRepositoryError.decoding(String(describing: error))
        } catch {
            throw NotesRepositoryError.network(error.localizedDescription)
        }
    }
}

private struct NoteInsert: Encodable {
    let content: String
    let parentId: String?
    let source: String
}

private struct NoteTagRow: Decodable {
    let noteID: String
    let tag: Tag

    private enum CodingKeys: String, CodingKey {
        case noteID = "noteId"
        case tag = "tags"
    }
}
