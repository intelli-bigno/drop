package com.intellieffect.drop.core

import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.client.engine.mock.respondError
import io.ktor.client.request.HttpRequestData
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpMethod
import io.ktor.http.HttpStatusCode
import io.ktor.http.content.TextContent
import io.ktor.http.headersOf
import io.ktor.utils.io.ByteReadChannel
import java.io.IOException
import java.time.Clock
import java.time.Instant
import java.time.ZoneOffset
import kotlin.coroutines.cancellation.CancellationException
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertTrue
import kotlinx.coroutines.test.runTest

/**
 * PostgREST 호출을 실제 네트워크 없이 검증한다.
 *
 * 여기서 잡는 것: 목록 조립(노트+첨부+태그 3쿼리), RLS가 요구하는 `user_id`,
 * 휴지통·보관이 서로를 지우는지, 그리고 **취소가 오류로 둔갑하지 않는지**.
 */
class SupabaseNotesRepositoryTest {
    private val config = DropConfiguration(
        supabaseUrl = "https://example.supabase.co",
        supabaseAnonKey = "anon-key",
        googleWebClientId = "web",
    )
    private val now: Instant = Instant.ofEpochSecond(1_800_000_000)
    private val clock: Clock = Clock.fixed(now, ZoneOffset.UTC)

    private val requests = mutableListOf<HttpRequestData>()

    private class FakeTokens(
        private val token: String? = "access-token",
        override val userId: String? = "user-1",
    ) : AuthTokenProvider {
        override suspend fun accessToken(): String? = token
    }

    private fun repository(
        tokens: AuthTokenProvider = FakeTokens(),
        handler: suspend io.ktor.client.engine.mock.MockRequestHandleScope.(HttpRequestData) ->
        io.ktor.client.request.HttpResponseData,
    ): SupabaseNotesRepository {
        val engine = MockEngine { request ->
            requests += request
            handler(request)
        }
        return SupabaseNotesRepository(config, supabaseHttpClient(engine), tokens, clock)
    }

    private fun io.ktor.client.engine.mock.MockRequestHandleScope.json(body: String) = respond(
        content = ByteReadChannel(body),
        status = HttpStatusCode.OK,
        headers = headersOf(HttpHeaders.ContentType, "application/json"),
    )

    private fun noteJson(
        id: String,
        content: String = "내용",
        pinned: Boolean = false,
        createdAt: String = "2026-08-17T07:00:00Z",
    ) = """
        {
          "id": "$id", "display_id": 7, "content": "$content",
          "created_at": "$createdAt", "updated_at": "$createdAt",
          "source": "mobile", "is_pinned": $pinned, "priority": 0
        }
    """.trimIndent()

    /** 목록은 노트·첨부·태그 세 쿼리를 합쳐 만든다. */
    @Test
    fun `목록을 노트 첨부 태그로 조립한다`() = runTest {
        val repository = repository { request ->
            when {
                request.url.encodedPath.endsWith("/notes") ->
                    json("[${noteJson("n1")},${noteJson("n2")}]")

                request.url.encodedPath.endsWith("/attachments") -> json(
                    """
                    [{"id":"a1","note_id":"n1","type":"image","storage_path":"u/n1/1.png",
                      "created_at":"2026-08-17T07:00:00Z"}]
                    """.trimIndent(),
                )

                request.url.encodedPath.endsWith("/note_tags") -> json(
                    """
                    [{"note_id":"n2","tags":{"id":"t1","name":"work",
                       "created_at":"2026-08-17T07:00:00Z"}}]
                    """.trimIndent(),
                )

                else -> respondError(HttpStatusCode.NotFound)
            }
        }

        val notes = repository.loadNotes()

        assertEquals(2, notes.size)
        assertEquals(listOf("a1"), notes.first { it.id == "n1" }.attachments.map { it.id })
        assertEquals(listOf("work"), notes.first { it.id == "n2" }.tags.map { it.name })
        // 토큰과 anon key가 모든 요청에 붙어야 한다 — 빠지면 RLS가 전부 막는다.
        assertTrue(requests.all { it.headers["Authorization"] == "Bearer access-token" })
        assertTrue(requests.all { it.headers["apikey"] == "anon-key" })
    }

    /** 노트가 없으면 첨부·태그를 물을 이유가 없다 (`in.()`은 문법 오류이기도 하다). */
    @Test
    fun `노트가 없으면 뒤따르는 쿼리를 보내지 않는다`() = runTest {
        val repository = repository { json("[]") }

        assertTrue(repository.loadNotes().isEmpty())
        assertEquals(1, requests.size)
    }

    @Test
    fun `보관과 휴지통 노트도 함께 받아 온다`() = runTest {
        val repository = repository { request ->
            if (request.url.encodedPath.endsWith("/notes")) {
                json(
                    """
                    [{"id":"n1","display_id":1,"content":"보관","created_at":"2026-08-17T07:00:00Z",
                      "updated_at":"2026-08-17T07:00:00Z","source":"mobile",
                      "archived_at":"2026-08-17T07:10:00Z"},
                     {"id":"n2","display_id":2,"content":"휴지통","created_at":"2026-08-17T06:00:00Z",
                      "updated_at":"2026-08-17T06:00:00Z","source":"mcp","is_deleted":true,
                      "deleted_at":"2026-08-17T07:20:00Z"}]
                    """.trimIndent(),
                )
            } else {
                json("[]")
            }
        }

        val notes = repository.loadNotes()

        assertTrue(notes.first { it.id == "n1" }.isArchived)
        assertTrue(notes.first { it.id == "n2" }.isInTrash)
        assertEquals(NoteSource.MCP, notes.first { it.id == "n2" }.source)
    }

    /** 서버가 모르는 source를 보내도 목록 전체가 깨지면 안 된다. */
    @Test
    fun `모르는 source는 unknown으로 읽는다`() = runTest {
        val repository = repository { request ->
            if (request.url.encodedPath.endsWith("/notes")) {
                json("[${noteJson("n1").replace("\"mobile\"", "\"telepathy\"")}]")
            } else {
                json("[]")
            }
        }

        assertEquals(NoteSource.UNKNOWN, repository.loadNotes().single().source)
    }

    /**
     * INSERT 정책이 `user_id = auth.uid()`를 요구하고 컬럼에 기본값이 없다.
     * 빠뜨리면 NULL이 들어가 RLS가 거부한다 (iOS에서 실측된 함정).
     */
    @Test
    fun `노트를 만들 때 user_id와 source를 함께 보낸다`() = runTest {
        val repository = repository { json("[${noteJson("new", content = "새 노트")}]") }

        val created = repository.createNote("새 노트", parentId = null)

        assertEquals("새 노트", created.content)
        val body = requests.single().bodyText()
        assertTrue(body.contains("\"user_id\":\"user-1\""), body)
        assertTrue(body.contains("\"source\":\"mobile\""), body)
        assertEquals("return=representation", requests.single().headers["Prefer"])
    }

    @Test
    fun `로그인 세션이 없으면 인증 오류다`() = runTest {
        val repository = repository(tokens = FakeTokens(token = null, userId = null)) { json("[]") }

        assertFailsWith<NotesRepositoryException.NotAuthenticated> { repository.loadNotes() }
        assertFailsWith<NotesRepositoryException.NotAuthenticated> { repository.createNote("x") }
    }

    /** 휴지통으로 보낼 때 보관을 함께 풀지 않으면 양쪽 목록에 다 나타난다. Rule B (BRU-115). */
    @Test
    fun `휴지통으로 보내면 보관도 함께 해제한다`() = runTest {
        val repository = repository { json("[]") }

        repository.moveToTrash("n1")

        val request = requests.single()
        assertEquals(HttpMethod.Patch, request.method)
        assertTrue(request.url.encodedQuery.contains("id=eq.n1"))
        val body = request.bodyText()
        assertTrue(body.contains("\"is_deleted\":true"), body)
        assertTrue(body.contains("\"archived_at\":null"), body)
        assertTrue(body.contains(PostgresTimestamp.format(now)), body)
    }

    @Test
    fun `복원해도 보관을 다시 살리지 않는다`() = runTest {
        val repository = repository { json("[]") }

        repository.restoreFromTrash("n1")

        val body = requests.single().bodyText()
        assertTrue(body.contains("\"is_deleted\":false"), body)
        assertTrue(body.contains("\"deleted_at\":null"), body)
        assertTrue(body.contains("\"archived_at\":null"), body)
    }

    @Test
    fun `고정을 풀면 고정 시각을 비운다`() = runTest {
        val repository = repository { json("[]") }

        repository.setPinned("n1", false)

        assertTrue(requests.single().bodyText().contains("\"pinned_at\":null"))
    }

    /** DB CHECK 제약(0-3)에 걸리기 전에 클라이언트에서 자른다. */
    @Test
    fun `우선순위는 0에서 3 사이로 자른다`() = runTest {
        val repository = repository { json("[]") }

        repository.setPriority("n1", 9)

        assertTrue(requests.single().bodyText().contains("\"priority\":3"))
    }

    @Test
    fun `휴지통 비우기는 내 노트의 삭제된 것만 지운다`() = runTest {
        val repository = repository { respond(ByteReadChannel(""), HttpStatusCode.NoContent) }

        repository.emptyTrash()

        val request = requests.single()
        assertEquals(HttpMethod.Delete, request.method)
        assertTrue(request.url.encodedQuery.contains("user_id=eq.user-1"))
        assertTrue(request.url.encodedQuery.contains("deleted_at=not.is.null"))
    }

    @Test
    fun `서버가 거절하면 이유를 담아 던진다`() = runTest {
        val repository = repository {
            respond(
                content = ByteReadChannel(
                    """{"message":"new row violates row-level security policy"}""",
                ),
                status = HttpStatusCode.Forbidden,
                headers = headersOf(HttpHeaders.ContentType, "application/json"),
            )
        }

        val error = assertFailsWith<NotesRepositoryException.Rejected> { repository.createNote("x") }
        assertTrue(error.reason.contains("row-level security"))
    }

    @Test
    fun `401은 인증 오류로 좁힌다`() = runTest {
        val repository = repository { respondError(HttpStatusCode.Unauthorized) }

        assertFailsWith<NotesRepositoryException.NotAuthenticated> { repository.loadNotes() }
    }

    @Test
    fun `연결 실패는 네트워크 오류다`() = runTest {
        val repository = repository { throw IOException("끊김") }

        assertFailsWith<NotesRepositoryException.Network> { repository.loadNotes() }
    }

    /**
     * 당겨서 새로고침에서 손을 떼면 요청이 취소된다. 이것을 네트워크 장애로 바꾸면
     * 아무 잘못 없이 오류창이 뜨고 보고 있던 목록까지 지워진다 (iOS BRU-32).
     */
    @Test
    fun `취소는 네트워크 오류로 둔갑하지 않는다`() = runTest {
        val repository = repository { throw CancellationException("당겨서 새로고침 취소") }

        assertFailsWith<CancellationException> { repository.loadNotes() }
    }

    @Test
    fun `응답 모양이 다르면 해석 오류다`() = runTest {
        val repository = repository { json("""{"unexpected":"object"}""") }

        assertFailsWith<NotesRepositoryException.Decoding> { repository.loadNotes() }
    }
}

private fun HttpRequestData.bodyText(): String = (body as TextContent).text
