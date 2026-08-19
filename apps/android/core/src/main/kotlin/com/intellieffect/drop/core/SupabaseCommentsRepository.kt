package com.intellieffect.drop.core

import io.ktor.client.HttpClient
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put

/**
 * `CommentsRepository`의 Supabase 구현 (BRU-86). PostgREST를 직접 부른다 —
 * iOS `SupabaseCommentsRepository`가 SDK로 하는 일과 같은 것이다.
 *
 * RLS가 "자기가 쓴, 자기 노트의 댓글"만 통과시키므로 쿼리에 사용자 조건을 다시 적지 않는다.
 * 헤더·오류 좁히기는 [SupabaseRest]가 맡는다.
 */
class SupabaseCommentsRepository(
    config: DropConfiguration,
    client: HttpClient,
    private val tokens: AuthTokenProvider,
) : CommentsRepository {
    private val rest = SupabaseRest(config, client, tokens)

    override suspend fun loadComments(noteId: String): List<NoteComment> {
        // 정렬을 서버에 맡긴다 — 페이지를 나눠 받게 되어도 순서가 유지된다.
        val rows: List<CommentRow> =
            rest.get("note_comments?select=*&note_id=eq.$noteId&order=created_at.asc")
        return rows.map { it.toComment() }
    }

    override suspend fun loadCommentCounts(): Map<String, Int> {
        // note_id만 받아 클라이언트에서 센다. 집계 함수를 쓰려면 뷰나 RPC가 필요한데,
        // 댓글 수는 개인 노트 규모에서 수백 행을 넘지 않는다.
        val rows: List<CommentNoteIdRow> = rest.get("note_comments?select=note_id")
        return rows.groupingBy { it.noteId }.eachCount()
    }

    override suspend fun createComment(noteId: String, body: String): NoteComment {
        // notes와 같은 이유로 user_id를 직접 넣는다 — 컬럼에 기본값이 없고
        // INSERT 정책이 user_id = auth.uid()를 요구한다.
        val userId = tokens.userId ?: throw NotesRepositoryException.NotAuthenticated

        val created: List<CommentRow> = rest.postReturning(
            path = "note_comments?select=*",
            body = buildJsonObject {
                put("note_id", noteId)
                put("user_id", userId)
                put("body", body)
            },
        )
        return created.firstOrNull()?.toComment()
            ?: throw NotesRepositoryException.Decoding("삽입된 댓글이 응답에 없습니다")
    }

    override suspend fun deleteComment(id: String) {
        // 하드 삭제 — 댓글에는 휴지통이 없다.
        rest.delete("note_comments?id=eq.$id")
    }
}
