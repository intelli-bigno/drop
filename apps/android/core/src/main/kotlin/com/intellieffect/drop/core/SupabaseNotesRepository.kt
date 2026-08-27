package com.intellieffect.drop.core

import io.ktor.client.HttpClient
import java.time.Clock
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put

/**
 * `NotesRepository`의 Supabase 구현. PostgREST를 직접 부른다 (iOS
 * `SupabaseNotesRepository`가 SDK로 하는 일과 같은 것).
 *
 * 목록은 보관·휴지통까지 통째로 받아 화면에서 거른다 — iOS·데스크톱과 같은 구조라
 * 앱마다 목록이 어긋나지 않는다. 헤더·오류 좁히기는 [SupabaseRest]가 맡는다.
 */
class SupabaseNotesRepository(
    config: DropConfiguration,
    client: HttpClient,
    private val tokens: AuthTokenProvider,
    private val clock: Clock = Clock.systemUTC(),
) : NotesRepository {
    private val rest = SupabaseRest(config, client, tokens)

    override suspend fun loadNotes(): List<Note> {
        val rows: List<NoteRow> = rest.get("notes?select=*&order=created_at.desc")
        if (rows.isEmpty()) return emptyList()

        val notes = rows.map { it.toNote() }
        val ids = notes.joinToString(",") { it.id }

        val attachments: List<AttachmentRow> =
            rest.get("attachments?select=*&note_id=in.($ids)&order=created_at.asc")
        val noteTags: List<NoteTagRow> =
            rest.get("note_tags?select=note_id,tags(*)&note_id=in.($ids)")

        return NoteAssembler.sorted(
            NoteAssembler.assemble(
                notes = notes,
                attachments = attachments.map { it.toAttachment() },
                tagsByNoteId = noteTags.mapNotNull { row -> row.tags?.let { row.noteId to it.toTag() } }
                    .groupBy({ it.first }, { it.second }),
            ),
        )
    }

    override suspend fun createNote(content: String, parentId: String?): Note {
        // user_id를 반드시 실어 보낸다. INSERT 정책이 user_id = auth.uid()를 요구하는데
        // 컬럼에 기본값이 없어서, 빠뜨리면 NULL이 들어가 RLS가 거부한다.
        val userId = tokens.userId ?: throw NotesRepositoryException.NotAuthenticated

        val created: List<NoteRow> = rest.postReturning(
            path = "notes?select=*",
            body = buildJsonObject {
                put("content", content)
                parentId?.let { put("parent_id", it) }
                put("user_id", userId)
                put("source", "mobile")
            },
        )
        return created.firstOrNull()?.toNote()
            ?: throw NotesRepositoryException.Decoding("삽입된 노트가 응답에 없습니다")
    }

    override suspend fun updateNote(id: String, content: String) =
        patch(id, buildJsonObject { put("content", content) })

    override suspend fun moveToTrash(id: String) = patch(
        id,
        buildJsonObject {
            put("is_deleted", true)
            put("deleted_at", nowTimestamp())
            // Rule B (BRU-115): 복원은 받은편지함으로. 보관을 남기면 휴지통·보관함 양쪽에 나타난다.
            put("archived_at", JsonNull)
        },
    )

    override suspend fun restoreFromTrash(id: String) = patch(
        id,
        buildJsonObject {
            put("is_deleted", false)
            put("deleted_at", JsonNull)
            put("archived_at", JsonNull)
        },
    )

    override suspend fun archive(id: String) =
        patch(id, buildJsonObject { put("archived_at", nowTimestamp()) })

    override suspend fun unarchive(id: String) =
        patch(id, buildJsonObject { put("archived_at", JsonNull) })

    override suspend fun deletePermanently(id: String) {
        rest.delete("notes?id=eq.$id")
    }

    override suspend fun emptyTrash() {
        val userId = tokens.userId ?: throw NotesRepositoryException.NotAuthenticated
        rest.delete("notes?user_id=eq.$userId&deleted_at=not.is.null")
    }

    override suspend fun setPinned(id: String, isPinned: Boolean) = patch(
        id,
        buildJsonObject {
            put("is_pinned", isPinned)
            put("pinned_at", if (isPinned) JsonPrimitive(nowTimestamp()) else JsonNull)
        },
    )

    override suspend fun setLocked(id: String, isLocked: Boolean) =
        patch(id, buildJsonObject { put("is_locked", isLocked) })

    override suspend fun setPriority(id: String, priority: Int) =
        // DB CHECK 제약(0-3)에 걸리지 않도록 클라이언트에서 먼저 자른다.
        patch(id, buildJsonObject { put("priority", priority.coerceIn(0, 3)) })

    override suspend fun updateCategories(
        id: String,
        hasLink: Boolean,
        hasMedia: Boolean,
        hasFiles: Boolean,
    ) = patch(
        id,
        buildJsonObject {
            put("has_link", hasLink)
            put("has_media", hasMedia)
            put("has_files", hasFiles)
        },
    )

    private suspend fun patch(id: String, values: JsonObject) = rest.patch("notes?id=eq.$id", values)

    private fun nowTimestamp(): String = PostgresTimestamp.format(clock.instant())
}
