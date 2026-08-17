import Foundation
import Supabase

/// `note_comments` 테이블에 붙는 구현. RLS가 "자기가 쓴, 자기 노트의 댓글"만 통과시키므로
/// 쿼리에 사용자 조건을 다시 적지 않는다.
public struct SupabaseCommentsRepository: CommentsRepository {
    private let client: SupabaseClient

    public init(client: SupabaseClient) {
        self.client = client
    }

    public func loadComments(noteID: String) async throws -> [NoteComment] {
        try await run {
            try await client.from("note_comments")
                .select()
                .eq("note_id", value: noteID)
                .order("created_at")
                .execute().value
        }
    }

    public func loadCommentCounts() async throws -> [String: Int] {
        // note_id만 받아 클라이언트에서 센다. 집계 함수를 쓰려면 뷰나 RPC가 필요한데,
        // 댓글 수는 개인 노트 규모에서 수백 행을 넘지 않는다.
        let rows: [CommentNoteIDRow] = try await run {
            try await client.from("note_comments").select("note_id").execute().value
        }
        return rows.reduce(into: [:]) { counts, row in
            counts[row.noteID, default: 0] += 1
        }
    }

    public func createComment(noteID: String, body: String) async throws -> NoteComment {
        // notes와 같은 이유로 user_id를 직접 넣는다 — 컬럼에 기본값이 없고
        // INSERT 정책이 user_id = auth.uid()를 요구한다.
        guard let user = client.auth.currentUser else { throw NotesRepositoryError.notAuthenticated }

        return try await run {
            try await client.from("note_comments")
                .insert(CommentInsert(noteID: noteID, userID: user.id.uuidString, body: body))
                .select()
                .single()
                .execute().value
        }
    }

    public func deleteComment(id: String) async throws {
        _ = try await run {
            try await client.from("note_comments").delete().eq("id", value: id).execute()
        }
    }

    /// Supabase/PostgREST 오류를 화면이 다룰 수 있는 형태로 좁힌다.
    private func run<T>(_ operation: () async throws -> T) async throws -> T {
        do {
            return try await operation()
        } catch where error.isCancellation {
            // 취소는 그대로 올려 보낸다 — 네트워크 장애로 둔갑하면 안 된다.
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

struct CommentInsert: Encodable {
    let noteID: String
    let userID: String
    let body: String

    private enum CodingKeys: String, CodingKey {
        case noteID = "noteId"
        case userID = "userId"
        case body
    }
}

/// 개수 집계용 최소 행.
private struct CommentNoteIDRow: Decodable {
    let noteID: String

    private enum CodingKeys: String, CodingKey {
        case noteID = "noteId"
    }
}
