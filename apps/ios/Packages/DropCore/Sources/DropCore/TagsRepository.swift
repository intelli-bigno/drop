import Foundation
import Supabase

public struct TagWithCount: Sendable, Equatable, Identifiable {
    public let tag: Tag
    public let noteCount: Int
    public let lastUsedAt: Date?

    public var id: String { tag.id }

    public init(tag: Tag, noteCount: Int, lastUsedAt: Date?) {
        self.tag = tag
        self.noteCount = noteCount
        self.lastUsedAt = lastUsedAt
    }
}

public protocol TagsRepository: Sendable {
    func loadTags() async throws -> [TagWithCount]
    /// 이름이 같은 태그가 있으면 재사용하고, 없으면 만든다.
    func addTag(named name: String, toNote noteID: String) async throws
    func removeTag(id tagID: String, fromNote noteID: String) async throws
    func renameTag(id tagID: String, to newName: String) async throws
    func deleteTag(id tagID: String) async throws
}

public struct SupabaseTagsRepository: TagsRepository {
    private let client: SupabaseClient

    public init(client: SupabaseClient) {
        self.client = client
    }

    public func loadTags() async throws -> [TagWithCount] {
        let rows: [TagCountRow] = try await run {
            try await client.from("tags")
                .select("*, note_tags(count)")
                .order("last_used_at", ascending: false, nullsFirst: false)
                .execute().value
        }
        return rows.map(\.asTagWithCount)
    }

    public func addTag(named name: String, toNote noteID: String) async throws {
        // 공백뿐인 이름은 태그가 아니다. 대소문자·공백 차이로 같은 태그가
        // 둘로 갈라지지 않도록 정규화한 뒤 조회한다.
        guard let normalized = TagName.normalized(name) else { return }
        // notes와 같은 이유로 user_id를 직접 넣어야 한다 (기본값 없음 + RLS WITH CHECK).
        guard let user = client.auth.currentUser else { throw NotesRepositoryError.notAuthenticated }
        let timestamp = ISO8601DateFormatter().string(from: Date())

        let existing: Tag? = try await run {
            try await client.from("tags").select().eq("name", value: normalized)
                .limit(1).execute().value as [Tag]
        }.first

        let tagID: String
        if let existing {
            tagID = existing.id
            try await run {
                _ = try await client.from("tags")
                    .update(["last_used_at": AnyJSON.string(timestamp)])
                    .eq("id", value: existing.id)
                    .execute()
            }
        } else {
            let created: Tag = try await run {
                try await client.from("tags")
                    .insert(TagInsert(
                        name: normalized,
                        userID: user.id.uuidString,
                        lastUsedAt: Date()
                    ))
                    .select()
                    .single()
                    .execute().value
            }
            tagID = created.id
        }

        // 이미 연결돼 있으면 조용히 넘어가야 한다 — 중복 연결은 오류가 아니다.
        try await run {
            _ = try await client.from("note_tags")
                .upsert(["note_id": AnyJSON.string(noteID), "tag_id": .string(tagID)])
                .execute()
        }
    }

    public func removeTag(id tagID: String, fromNote noteID: String) async throws {
        try await run {
            _ = try await client.from("note_tags").delete()
                .eq("note_id", value: noteID)
                .eq("tag_id", value: tagID)
                .execute()
        }
    }

    public func renameTag(id tagID: String, to newName: String) async throws {
        guard let normalized = TagName.normalized(newName) else { return }
        try await run {
            _ = try await client.from("tags")
                .update(["name": AnyJSON.string(normalized)])
                .eq("id", value: tagID)
                .execute()
        }
    }

    public func deleteTag(id tagID: String) async throws {
        // note_tags는 CASCADE로 함께 지워진다.
        try await run {
            _ = try await client.from("tags").delete().eq("id", value: tagID).execute()
        }
    }

    private func run<T>(_ operation: () async throws -> T) async throws -> T {
        do {
            return try await operation()
        } catch where error.isCancellation {
            throw error
        } catch let error as PostgrestError {
            throw NotesRepositoryError.rejected(error.message)
        } catch let error as DecodingError {
            throw NotesRepositoryError.decoding(String(describing: error))
        } catch {
            throw NotesRepositoryError.network(error.localizedDescription)
        }
    }
}

struct TagInsert: Encodable {
    let name: String
    let userID: String
    let lastUsedAt: Date

    private enum CodingKeys: String, CodingKey {
        case name
        case userID = "userId"
        case lastUsedAt
    }
}

/// `tags` 행 + `note_tags(count)` 집계.
struct TagCountRow: Decodable {
    let id: String
    let name: String
    let createdAt: Date
    let lastUsedAt: Date?
    let noteTags: [CountRow]?

    struct CountRow: Decodable { let count: Int }

    var asTagWithCount: TagWithCount {
        TagWithCount(
            tag: Tag(id: id, name: name, createdAt: createdAt),
            noteCount: noteTags?.first?.count ?? 0,
            lastUsedAt: lastUsedAt
        )
    }
}
