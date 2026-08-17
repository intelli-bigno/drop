package com.intellieffect.drop.core

import io.ktor.client.HttpClient
import io.ktor.client.call.body
import io.ktor.client.request.HttpRequestBuilder
import io.ktor.client.request.delete
import io.ktor.client.request.get
import io.ktor.client.request.header
import io.ktor.client.request.patch
import io.ktor.client.request.post
import io.ktor.client.request.setBody
import io.ktor.client.statement.HttpResponse
import io.ktor.http.ContentType
import io.ktor.http.HttpStatusCode
import io.ktor.http.contentType
import io.ktor.http.isSuccess
import java.time.Clock
import kotlin.coroutines.cancellation.CancellationException
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
 * 앱마다 목록이 어긋나지 않는다.
 */
class SupabaseNotesRepository(
    private val config: DropConfiguration,
    private val client: HttpClient,
    private val tokens: AuthTokenProvider,
    private val clock: Clock = Clock.systemUTC(),
) : NotesRepository {
    override suspend fun loadNotes(): List<Note> {
        val rows: List<NoteRow> = get("notes?select=*&order=created_at.desc")
        if (rows.isEmpty()) return emptyList()

        val notes = rows.map { it.toNote() }
        val ids = notes.joinToString(",") { it.id }

        val attachments: List<AttachmentRow> =
            get("attachments?select=*&note_id=in.($ids)&order=created_at.asc")
        val noteTags: List<NoteTagRow> =
            get("note_tags?select=note_id,tags(*)&note_id=in.($ids)")

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
        val userId = requireUserId()

        val response = request {
            post("${config.supabaseUrl}/rest/v1/notes?select=*") {
                authorize()
                // 이걸 빼면 삽입된 행이 응답에 오지 않아 목록에 끼워 넣을 수 없다.
                header("Prefer", "return=representation")
                contentType(ContentType.Application.Json)
                setBody(
                    buildJsonObject {
                        put("content", content)
                        parentId?.let { put("parent_id", it) }
                        put("user_id", userId)
                        put("source", "mobile")
                    },
                )
            }
        }

        val created: List<NoteRow> = decode(response)
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
            // 보관 해제를 함께 하지 않으면 휴지통과 보관함 양쪽에 나타난다.
            put("archived_at", JsonNull)
        },
    )

    override suspend fun restoreFromTrash(id: String) = patch(
        id,
        buildJsonObject {
            put("is_deleted", false)
            put("deleted_at", JsonNull)
        },
    )

    override suspend fun archive(id: String) =
        patch(id, buildJsonObject { put("archived_at", nowTimestamp()) })

    override suspend fun unarchive(id: String) =
        patch(id, buildJsonObject { put("archived_at", JsonNull) })

    override suspend fun deletePermanently(id: String) {
        request { delete("${config.supabaseUrl}/rest/v1/notes?id=eq.$id") { authorize() } }
    }

    override suspend fun emptyTrash() {
        val userId = requireUserId()
        request {
            delete("${config.supabaseUrl}/rest/v1/notes?user_id=eq.$userId&deleted_at=not.is.null") {
                authorize()
            }
        }
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

    // MARK: - 내부

    private suspend fun requireUserId(): String =
        tokens.userId ?: throw NotesRepositoryException.NotAuthenticated

    private suspend fun patch(id: String, values: JsonObject) {
        request {
            patch("${config.supabaseUrl}/rest/v1/notes?id=eq.$id") {
                authorize()
                contentType(ContentType.Application.Json)
                setBody(values)
            }
        }
    }

    private suspend inline fun <reified T> get(path: String): T =
        decode(request { get("${config.supabaseUrl}/rest/v1/$path") { authorize() } })

    private suspend fun HttpRequestBuilder.authorize() {
        val token = tokens.accessToken() ?: throw NotesRepositoryException.NotAuthenticated
        header("apikey", config.supabaseAnonKey)
        header("Authorization", "Bearer $token")
    }

    /**
     * 오류를 화면이 다룰 수 있는 형태로 좁힌다. **취소는 그대로 올려 보낸다** —
     * 네트워크 장애로 둔갑하면 당겨서 새로고침을 놓은 것만으로 오류창이 뜬다.
     */
    private suspend fun request(operation: suspend HttpClient.() -> HttpResponse): HttpResponse {
        val response = try {
            client.operation()
        } catch (cancellation: CancellationException) {
            throw cancellation
        } catch (error: NotesRepositoryException) {
            throw error
        } catch (error: Throwable) {
            throw NotesRepositoryException.Network(error.message ?: error.toString())
        }

        if (response.status.isSuccess()) return response

        val message = response.supabaseErrorMessage()
        throw when {
            // 토큰이 죽었거나 RLS가 막은 것. 화면은 "로그인이 필요합니다"로 안내한다.
            response.status == HttpStatusCode.Unauthorized -> NotesRepositoryException.NotAuthenticated
            response.status.value >= HttpStatusCode.InternalServerError.value ->
                NotesRepositoryException.Network(message)
            else -> NotesRepositoryException.Rejected(message)
        }
    }

    private suspend inline fun <reified T> decode(response: HttpResponse): T = try {
        response.body()
    } catch (cancellation: CancellationException) {
        throw cancellation
    } catch (error: Throwable) {
        throw NotesRepositoryException.Decoding(error.message ?: error.toString())
    }

    private fun nowTimestamp(): String = PostgresTimestamp.format(clock.instant())
}
