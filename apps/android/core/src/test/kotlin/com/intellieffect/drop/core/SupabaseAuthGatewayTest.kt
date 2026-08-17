package com.intellieffect.drop.core

import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.MockRequestHandleScope
import io.ktor.client.engine.mock.respond
import io.ktor.client.engine.mock.respondError
import io.ktor.client.request.HttpRequestData
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import io.ktor.client.request.HttpResponseData
import io.ktor.http.content.TextContent
import io.ktor.utils.io.ByteReadChannel
import java.io.IOException
import java.time.Clock
import java.time.Instant
import java.time.ZoneOffset
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertNull
import kotlin.test.assertTrue
import kotlinx.coroutines.test.runTest

/**
 * 인증 REST 호출을 실제 네트워크 없이 검증한다. 여기서 잡는 것은 세 가지다 —
 * 요청이 제대로 나가는지, 만료된 세션이 알아서 갱신되는지, 죽은 세션을 버리는지.
 */
class SupabaseAuthGatewayTest {
    private val config = DropConfiguration(
        supabaseUrl = "https://example.supabase.co",
        supabaseAnonKey = "anon-key",
        googleWebClientId = "web-client",
    )
    private val now: Instant = Instant.ofEpochSecond(1_800_000_000)
    private val clock: Clock = Clock.fixed(now, ZoneOffset.UTC)

    private val requests = mutableListOf<HttpRequestData>()

    private fun gateway(
        storage: SessionStorage = InMemorySessionStorage(),
        handler: suspend MockRequestHandleScope.(HttpRequestData) -> HttpResponseData,
    ): SupabaseAuthGateway {
        val engine = MockEngine { request ->
            requests += request
            handler(request)
        }
        return SupabaseAuthGateway(config, supabaseHttpClient(engine), storage, clock)
    }

    private fun MockRequestHandleScope.tokenResponse(
        accessToken: String = "access-1",
        refreshToken: String = "refresh-1",
        expiresIn: Long = 3600,
    ) = respond(
        content = ByteReadChannel(
            """
            {
              "access_token": "$accessToken",
              "refresh_token": "$refreshToken",
              "expires_in": $expiresIn,
              "user": { "id": "user-1", "email": "bruce@intellieffect.com" }
            }
            """.trimIndent(),
        ),
        status = HttpStatusCode.OK,
        headers = headersOf(HttpHeaders.ContentType, "application/json"),
    )

    @Test
    fun `구글 id_token으로 로그인하면 세션이 저장된다`() = runTest {
        val storage = InMemorySessionStorage()
        val gateway = gateway(storage) { tokenResponse() }

        val session = gateway.signIn(GoogleIdentity(idToken = "google-id-token"))

        assertEquals("access-1", session.accessToken)
        assertEquals("user-1", session.user.id)
        assertEquals(now.plusSeconds(3600), session.expiresAt)
        // 앱을 다시 켜도 로그인 상태가 남아야 한다.
        assertEquals("access-1", storage.load()?.accessToken)

        val request = requests.single()
        assertEquals("id_token", request.url.parameters["grant_type"])
        assertEquals("anon-key", request.headers["apikey"])
        assertTrue(request.bodyText().contains("\"provider\":\"google\""))
        assertTrue(request.bodyText().contains("google-id-token"))
    }

    /** `expires_at`(절대 시각)이 오면 그것을 그대로 믿는다. */
    @Test
    fun `expires_at이 오면 그 시각을 쓴다`() = runTest {
        val gateway = gateway {
            respond(
                content = ByteReadChannel(
                    """
                    {
                      "access_token": "a", "refresh_token": "r",
                      "expires_in": 3600, "expires_at": 1900000000,
                      "user": { "id": "user-1" }
                    }
                    """.trimIndent(),
                ),
                status = HttpStatusCode.OK,
                headers = headersOf(HttpHeaders.ContentType, "application/json"),
            )
        }

        assertEquals(
            Instant.ofEpochSecond(1_900_000_000),
            gateway.signIn(GoogleIdentity("id")).expiresAt,
        )
    }

    @Test
    fun `거부되면 서버 문구를 담아 던진다`() = runTest {
        val gateway = gateway {
            respond(
                content = ByteReadChannel("""{"error":"invalid_grant","error_description":"Unacceptable audience"}"""),
                status = HttpStatusCode.BadRequest,
                headers = headersOf(HttpHeaders.ContentType, "application/json"),
            )
        }

        val error = assertFailsWith<AuthException.Rejected> { gateway.signIn(GoogleIdentity("id")) }
        assertEquals("Unacceptable audience", error.reason)
    }

    /** 5xx는 서버가 흔들린 것이다. 재로그인해도 달라지지 않으므로 거절과 구분한다. */
    @Test
    fun `5xx는 네트워크 실패로 다룬다`() = runTest {
        val gateway = gateway { respondError(HttpStatusCode.BadGateway) }

        assertFailsWith<AuthException.Network> { gateway.signIn(GoogleIdentity("id")) }
    }

    @Test
    fun `만료된 세션은 복원 시점에 갱신된다`() = runTest {
        val storage = InMemorySessionStorage(
            Session("old-access", "old-refresh", now.minusSeconds(10), DropUser("user-1", null)),
        )
        val gateway = gateway(storage) { tokenResponse(accessToken = "fresh-access") }

        val restored = gateway.restore()

        assertEquals("fresh-access", restored?.accessToken)
        assertEquals("refresh_token", requests.single().url.parameters["grant_type"])
        assertTrue(requests.single().bodyText().contains("old-refresh"))
        assertEquals("fresh-access", storage.load()?.accessToken)
    }

    /** 아직 살아 있는 세션으로 갱신 요청을 보내면 리프레시 토큰을 낭비한다. */
    @Test
    fun `살아 있는 세션은 네트워크를 부르지 않는다`() = runTest {
        val storage = InMemorySessionStorage(
            Session("access", "refresh", now.plusSeconds(3600), DropUser("user-1", null)),
        )
        val gateway = gateway(storage) { tokenResponse() }

        assertEquals("access", gateway.restore()?.accessToken)
        assertEquals("access", gateway.accessToken())
        assertTrue(requests.isEmpty())
    }

    /**
     * 며칠 만에 앱을 켜면 리프레시 토큰까지 죽어 있다. 쓸 수 없는 세션을 들고 있으면
     * 모든 요청이 401로 실패하므로, 버리고 로그인 화면으로 돌아가야 한다.
     */
    @Test
    fun `갱신이 거부되면 세션을 버린다`() = runTest {
        val storage = InMemorySessionStorage(
            Session("old", "dead-refresh", now.minusSeconds(10), DropUser("user-1", null)),
        )
        val gateway = gateway(storage) {
            respond(
                content = ByteReadChannel("""{"error":"invalid_grant","error_description":"refresh token expired"}"""),
                status = HttpStatusCode.BadRequest,
                headers = headersOf(HttpHeaders.ContentType, "application/json"),
            )
        }

        assertNull(gateway.restore())
        assertNull(storage.load())
        assertNull(gateway.accessToken())
    }

    @Test
    fun `로그아웃하면 저장된 세션이 사라진다`() = runTest {
        val storage = InMemorySessionStorage(
            Session("access", "refresh", now.plusSeconds(3600), DropUser("user-1", null)),
        )
        val gateway = gateway(storage) { respond(ByteReadChannel(""), HttpStatusCode.NoContent) }

        gateway.signOut()

        assertNull(storage.load())
        assertNull(gateway.accessToken())
        assertEquals("Bearer access", requests.single().headers["Authorization"])
    }

    /** 네트워크가 죽어 있어도 로그아웃은 되어야 한다. */
    @Test
    fun `로그아웃 호출이 실패해도 로컬 세션은 끊는다`() = runTest {
        val storage = InMemorySessionStorage(
            Session("access", "refresh", now.plusSeconds(3600), DropUser("user-1", null)),
        )
        val gateway = gateway(storage) { throw IOException("끊김") }

        gateway.signOut()

        assertNull(storage.load())
    }
}

private fun HttpRequestData.bodyText(): String =
    (body as TextContent).text
