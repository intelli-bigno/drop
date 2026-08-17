package com.intellieffect.drop.core

import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.MockRequestHandleScope
import io.ktor.client.engine.mock.respond
import io.ktor.client.request.HttpRequestData
import io.ktor.client.request.HttpResponseData
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpMethod
import io.ktor.http.HttpStatusCode
import io.ktor.http.content.TextContent
import io.ktor.http.headersOf
import io.ktor.utils.io.ByteReadChannel
import java.time.Clock
import java.time.Instant
import java.time.ZoneOffset
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertTrue
import kotlinx.coroutines.test.runTest

/** 태그 편집 경로. iOS `SupabaseTagsRepository`와 같은 동작을 검증한다. */
class SupabaseTagsRepositoryTest {
    private val config = DropConfiguration(
        supabaseUrl = "https://example.supabase.co",
        supabaseAnonKey = "anon",
        googleWebClientId = "web",
    )
    private val now: Instant = Instant.ofEpochSecond(1_800_000_000)
    private val requests = mutableListOf<HttpRequestData>()

    private class FakeTokens(override val userId: String? = "user-1") : AuthTokenProvider {
        override suspend fun accessToken(): String? = "token"
    }

    private fun repository(
        tokens: AuthTokenProvider = FakeTokens(),
        handler: suspend MockRequestHandleScope.(HttpRequestData) -> HttpResponseData,
    ): SupabaseTagsRepository {
        val engine = MockEngine { request ->
            requests += request
            handler(request)
        }
        return SupabaseTagsRepository(
            config,
            supabaseHttpClient(engine),
            tokens,
            Clock.fixed(now, ZoneOffset.UTC),
        )
    }

    private fun MockRequestHandleScope.json(body: String) = respond(
        content = ByteReadChannel(body),
        status = HttpStatusCode.OK,
        headers = headersOf(HttpHeaders.ContentType, "application/json"),
    )

    /** 태그별 노트 수는 집계 임베딩으로 한 번에 받는다. */
    @Test
    fun `태그 목록에 노트 수가 함께 온다`() = runTest {
        val repository = repository {
            json(
                """
                [{"id":"t1","name":"work","created_at":"2026-08-17T07:00:00Z",
                  "last_used_at":"2026-08-17T07:30:00Z","note_tags":[{"count":3}]},
                 {"id":"t2","name":"life","created_at":"2026-08-17T07:00:00Z","note_tags":[]}]
                """.trimIndent(),
            )
        }

        val tags = repository.loadTags()

        assertEquals(listOf("work", "life"), tags.map { it.tag.name })
        assertEquals(3, tags[0].noteCount)
        // 아직 아무 노트에도 안 붙은 태그는 0이어야 한다 — 빠뜨리면 목록이 깨진다.
        assertEquals(0, tags[1].noteCount)
        assertEquals(1, requests.size)
    }

    /** 이름이 같은 태그가 있으면 새로 만들지 않고 재사용한다. */
    @Test
    fun `이미 있는 태그는 재사용하고 연결만 만든다`() = runTest {
        val repository = repository { request ->
            when {
                request.url.encodedPath.endsWith("/tags") && request.method == HttpMethod.Get ->
                    json("""[{"id":"t1","name":"work","created_at":"2026-08-17T07:00:00Z"}]""")

                else -> json("[]")
            }
        }

        repository.addTag("Work", noteId = "n1")

        // GET tags → PATCH tags(last_used_at) → POST note_tags
        assertEquals(3, requests.size)
        assertEquals(HttpMethod.Patch, requests[1].method)
        assertTrue(requests[1].bodyText().contains("last_used_at"))

        val link = requests[2]
        assertEquals(HttpMethod.Post, link.method)
        assertTrue(link.url.encodedPath.endsWith("/note_tags"))
        assertTrue(link.bodyText().contains("\"tag_id\":\"t1\""), link.bodyText())
        // 중복 연결은 오류가 아니다 — merge-duplicates로 조용히 넘어가야 한다.
        assertEquals("resolution=merge-duplicates", link.headers["Prefer"])
    }

    /** 대소문자·공백 차이로 같은 태그가 둘로 갈라지면 안 된다. */
    @Test
    fun `태그 이름을 소문자로 다듬어 조회한다`() = runTest {
        val repository = repository { request ->
            if (request.method == HttpMethod.Get) {
                json("[]")
            } else {
                json("""[{"id":"new","name":"work","created_at":"2026-08-17T07:00:00Z"}]""")
            }
        }

        repository.addTag("  Work  ", noteId = "n1")

        assertTrue(requests.first().url.encodedQuery.contains("name=eq.work"), requests.first().url.toString())
    }

    @Test
    fun `새 태그를 만들 때 user_id를 함께 보낸다`() = runTest {
        val repository = repository { request ->
            if (request.method == HttpMethod.Get) {
                json("[]")
            } else {
                json("""[{"id":"new","name":"work","created_at":"2026-08-17T07:00:00Z"}]""")
            }
        }

        repository.addTag("work", noteId = "n1")

        val insert = requests[1]
        assertEquals(HttpMethod.Post, insert.method)
        // RLS WITH CHECK가 user_id = auth.uid()를 요구하고 컬럼에 기본값이 없다.
        assertTrue(insert.bodyText().contains("\"user_id\":\"user-1\""), insert.bodyText())
        assertTrue(insert.bodyText().contains(PostgresTimestamp.format(now)))
    }

    @Test
    fun `공백뿐인 이름은 아무 요청도 만들지 않는다`() = runTest {
        val repository = repository { json("[]") }

        repository.addTag("   ", noteId = "n1")

        assertTrue(requests.isEmpty())
    }

    @Test
    fun `태그를 떼면 연결만 지운다`() = runTest {
        val repository = repository { respond(ByteReadChannel(""), HttpStatusCode.NoContent) }

        repository.removeTag(tagId = "t1", noteId = "n1")

        val request = requests.single()
        assertEquals(HttpMethod.Delete, request.method)
        assertTrue(request.url.encodedPath.endsWith("/note_tags"))
        assertTrue(request.url.encodedQuery.contains("note_id=eq.n1"))
        assertTrue(request.url.encodedQuery.contains("tag_id=eq.t1"))
    }

    @Test
    fun `이름을 바꿀 때도 다듬는다`() = runTest {
        val repository = repository { respond(ByteReadChannel(""), HttpStatusCode.NoContent) }

        repository.renameTag("t1", "  Deep Work ")

        assertTrue(requests.single().bodyText().contains("\"deep work\""), requests.single().bodyText())
    }

    @Test
    fun `태그를 지우면 태그 행을 지운다`() = runTest {
        val repository = repository { respond(ByteReadChannel(""), HttpStatusCode.NoContent) }

        repository.deleteTag("t1")

        assertTrue(requests.single().url.encodedPath.endsWith("/tags"))
        assertEquals(HttpMethod.Delete, requests.single().method)
    }

    @Test
    fun `로그인 세션이 없으면 태그를 만들지 않는다`() = runTest {
        val repository = repository(tokens = FakeTokens(userId = null)) { json("[]") }

        assertFailsWith<NotesRepositoryException.NotAuthenticated> {
            repository.addTag("work", noteId = "n1")
        }
    }
}

private fun HttpRequestData.bodyText(): String = (body as TextContent).text
