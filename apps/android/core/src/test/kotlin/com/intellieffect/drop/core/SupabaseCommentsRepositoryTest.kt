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
import kotlin.coroutines.cancellation.CancellationException
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertTrue
import kotlinx.coroutines.test.runTest

/**
 * `note_comments` PostgREST 호출을 실제 네트워크 없이 검증한다 (BRU-86).
 *
 * 여기서 잡는 것: 노트별 오래된 순 조회, RLS가 요구하는 `user_id`,
 * 개수를 한 번의 쿼리로 세는지, 그리고 **취소가 오류로 둔갑하지 않는지**.
 */
class SupabaseCommentsRepositoryTest {
    private val config = DropConfiguration(
        supabaseUrl = "https://example.supabase.co",
        supabaseAnonKey = "anon-key",
        googleWebClientId = "web",
    )

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
    ): SupabaseCommentsRepository {
        val engine = MockEngine { request ->
            requests += request
            handler(request)
        }
        return SupabaseCommentsRepository(config, supabaseHttpClient(engine), tokens)
    }

    private fun io.ktor.client.engine.mock.MockRequestHandleScope.json(body: String) = respond(
        content = ByteReadChannel(body),
        status = HttpStatusCode.OK,
        headers = headersOf(HttpHeaders.ContentType, "application/json"),
    )

    private fun commentJson(id: String, noteId: String, body: String, at: String) = """
        {"id":"$id","note_id":"$noteId","body":"$body","created_at":"$at","updated_at":"$at"}
    """.trimIndent()

    @Test
    fun `한 노트의 댓글을 오래된 순으로 조회한다`() = runTest {
        val repository = repository {
            json(
                "[${commentJson("c1", "n1", "먼저", "2026-08-17T07:00:00Z")}," +
                    "${commentJson("c2", "n1", "나중", "2026-08-17T08:00:00Z")}]",
            )
        }

        val comments = repository.loadComments("n1")

        assertEquals(listOf("먼저", "나중"), comments.map { it.body })
        val url = requests.single().url.toString()
        assertTrue(url.contains("note_comments"), url)
        assertTrue(url.contains("note_id=eq.n1"), url)
        // 정렬을 서버에 맡긴다 — 페이지를 나눠 받게 되어도 순서가 유지된다.
        assertTrue(url.contains("order=created_at"), url)
        // 토큰과 anon key가 없으면 RLS가 전부 막는다.
        assertEquals("Bearer access-token", requests.single().headers["Authorization"])
        assertEquals("anon-key", requests.single().headers["apikey"])
    }

    /**
     * 개수는 노트마다 세지 않는다 — 화면 하나에 수십 번의 왕복이 생긴다.
     * `note_id`만 받아 클라이언트에서 센다 (집계 함수는 뷰나 RPC가 필요한데,
     * 개인 노트 규모에서 댓글은 수백 행을 넘지 않는다).
     */
    @Test
    fun `개수는 한 번의 쿼리로 센다`() = runTest {
        val repository = repository {
            json("""[{"note_id":"n1"},{"note_id":"n1"},{"note_id":"n2"}]""")
        }

        val counts = repository.loadCommentCounts()

        assertEquals(mapOf("n1" to 2, "n2" to 1), counts)
        assertEquals(1, requests.size)
        assertTrue(requests.single().url.toString().contains("select=note_id"))
    }

    @Test
    fun `댓글이 없으면 빈 개수 맵이다`() = runTest {
        val repository = repository { json("[]") }

        assertTrue(repository.loadCommentCounts().isEmpty())
    }

    /**
     * INSERT 정책이 `user_id = auth.uid()`를 요구하는데 컬럼에 기본값이 없다 —
     * 빠뜨리면 NULL이 들어가 RLS가 거부한다 (notes와 같은 이유).
     */
    @Test
    fun `작성할 때 user_id를 실어 보낸다`() = runTest {
        val repository = repository {
            json("[${commentJson("c1", "n1", "확인.", "2026-08-17T07:00:00Z")}]")
        }

        val created = repository.createComment("n1", "확인.")

        assertEquals("c1", created.id)
        assertEquals("n1", created.noteId)
        val body = (requests.single().body as TextContent).text
        assertTrue(body.contains("\"user_id\":\"user-1\""), body)
        assertTrue(body.contains("\"note_id\":\"n1\""), body)
        assertTrue(body.contains("\"body\":\"확인.\""), body)
        // 삽입된 행이 응답에 오게 하는 헤더. 빠지면 빈 응답이 온다.
        assertEquals("return=representation", requests.single().headers["Prefer"])
    }

    @Test
    fun `로그인하지 않았으면 작성하지 않는다`() = runTest {
        val repository = repository(tokens = FakeTokens(userId = null)) {
            respondError(HttpStatusCode.InternalServerError)
        }

        assertFailsWith<NotesRepositoryException.NotAuthenticated> {
            repository.createComment("n1", "확인.")
        }
        // 보낼 수 없는 요청을 굳이 보내지 않는다.
        assertTrue(requests.isEmpty())
    }

    /** 댓글에는 휴지통이 없다 — DELETE 한 번으로 끝난다. */
    @Test
    fun `삭제는 하드 삭제다`() = runTest {
        val repository = repository { respond(ByteReadChannel(""), HttpStatusCode.NoContent) }

        repository.deleteComment("c1")

        assertEquals(HttpMethod.Delete, requests.single().method)
        assertTrue(requests.single().url.toString().contains("id=eq.c1"))
    }

    @Test
    fun `서버가 거절하면 문구를 그대로 올린다`() = runTest {
        val repository = repository {
            respond(
                content = ByteReadChannel("""{"message":"new row violates row-level security"}"""),
                status = HttpStatusCode.BadRequest,
                headers = headersOf(HttpHeaders.ContentType, "application/json"),
            )
        }

        val error = assertFailsWith<NotesRepositoryException.Rejected> {
            repository.createComment("n1", "확인.")
        }
        assertTrue(error.reason.contains("row-level security"))
    }

    /** 취소가 네트워크 장애로 둔갑하면 시트를 닫은 것만으로 오류창이 뜬다. */
    @Test
    fun `취소는 네트워크 오류로 둔갑하지 않는다`() = runTest {
        val repository = repository { throw CancellationException("시트를 닫음") }

        assertFailsWith<CancellationException> { repository.loadComments("n1") }
    }

    @Test
    fun `연결 실패는 네트워크 오류다`() = runTest {
        val repository = repository { throw IOException("끊김") }

        assertFailsWith<NotesRepositoryException.Network> { repository.loadComments("n1") }
    }
}
