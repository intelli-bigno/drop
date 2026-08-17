package com.intellieffect.drop.core

import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.MockRequestHandleScope
import io.ktor.client.engine.mock.respond
import io.ktor.client.engine.mock.respondError
import io.ktor.client.request.HttpRequestData
import io.ktor.client.request.HttpResponseData
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpMethod
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import io.ktor.utils.io.ByteReadChannel
import java.time.Clock
import java.time.Duration
import java.time.Instant
import java.time.ZoneOffset
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertTrue
import kotlinx.coroutines.test.runTest

/** 첨부 업로드·삭제·서명 URL. iOS `SupabaseAttachmentsRepository`와 같은 동작. */
class SupabaseAttachmentsRepositoryTest {
    private val config = DropConfiguration(
        supabaseUrl = "https://example.supabase.co",
        supabaseAnonKey = "anon",
        googleWebClientId = "web",
    )
    private val requests = mutableListOf<HttpRequestData>()

    private class FakeTokens(override val userId: String? = "user-1") : AuthTokenProvider {
        override suspend fun accessToken(): String? = "token"
    }

    private fun repository(
        tokens: AuthTokenProvider = FakeTokens(),
        handler: suspend MockRequestHandleScope.(HttpRequestData) -> HttpResponseData,
    ): SupabaseAttachmentsRepository {
        val engine = MockEngine { request ->
            requests += request
            handler(request)
        }
        return SupabaseAttachmentsRepository(config, supabaseHttpClient(engine), tokens)
    }

    private fun MockRequestHandleScope.json(body: String) = respond(
        content = ByteReadChannel(body),
        status = HttpStatusCode.OK,
        headers = headersOf(HttpHeaders.ContentType, "application/json"),
    )

    private val attachmentRowJson = """
        [{"id":"a1","note_id":"n1","type":"image","storage_path":"user-1/n1/1.png",
          "filename":"photo.png","mime_type":"image/png","size":4,
          "created_at":"2026-08-17T07:00:00Z"}]
    """.trimIndent()

    @Test
    fun `업로드는 스토리지에 올리고 행을 만든다`() = runTest {
        val repository = repository { request ->
            if (request.url.encodedPath.contains("/storage/")) {
                json("""{"Key":"attachments/user-1/n1/1.png"}""")
            } else {
                json(attachmentRowJson)
            }
        }

        val attachment = repository.upload(
            bytes = byteArrayOf(1, 2, 3, 4),
            fileName = "photo.png",
            type = AttachmentType.IMAGE,
            noteId = "n1",
        )

        assertEquals("a1", attachment.id)
        assertEquals(AttachmentType.IMAGE, attachment.type)

        val upload = requests.first()
        assertEquals(HttpMethod.Post, upload.method)
        // 경로 규칙은 iOS·Flutter와 같아야 한다: {user_id}/{note_id}/{고유값}.{확장자}
        assertTrue(
            upload.url.encodedPath.startsWith("/storage/v1/object/attachments/user-1/n1/"),
            upload.url.encodedPath,
        )
        assertTrue(upload.url.encodedPath.endsWith(".png"), upload.url.encodedPath)
        assertEquals("image/png", upload.body.contentType?.toString())

        val insert = requests[1]
        assertTrue(insert.url.encodedPath.endsWith("/attachments"))
    }

    /** 확장자가 없는 이름이 들어오면 종류별 기본 확장자를 쓴다. */
    @Test
    fun `확장자가 없으면 종류로 정한다`() = runTest {
        val repository = repository { request ->
            if (request.url.encodedPath.contains("/storage/")) json("{}") else json(attachmentRowJson)
        }

        repository.upload(byteArrayOf(1), "clip", AttachmentType.VIDEO, "n1")

        assertTrue(requests.first().url.encodedPath.endsWith(".mp4"), requests.first().url.encodedPath)
        assertEquals("video/mp4", requests.first().body.contentType?.toString())
    }

    /**
     * 스토리지에는 올라갔는데 행 생성이 실패하면 고아 파일이 남는다.
     * 두 저장소가 어긋난 채로 남지 않도록 올린 파일을 되돌려야 한다.
     */
    @Test
    fun `행 생성이 실패하면 올린 파일을 지운다`() = runTest {
        val repository = repository { request ->
            when {
                request.url.encodedPath.contains("/storage/") -> json("{}")
                else -> respondError(HttpStatusCode.Forbidden)
            }
        }

        assertFailsWith<NotesRepositoryException.Rejected> {
            repository.upload(byteArrayOf(1), "photo.png", AttachmentType.IMAGE, "n1")
        }

        val cleanup = requests.last()
        assertEquals(HttpMethod.Delete, cleanup.method)
        assertTrue(cleanup.url.encodedPath.contains("/storage/v1/object/attachments/"))
    }

    @Test
    fun `첨부를 지우면 행과 파일을 함께 지운다`() = runTest {
        val repository = repository { respond(ByteReadChannel(""), HttpStatusCode.NoContent) }
        val attachment = Attachment(
            id = "a1",
            noteId = "n1",
            type = AttachmentType.IMAGE,
            storagePath = "user-1/n1/1.png",
            createdAt = Instant.EPOCH,
        )

        repository.delete(attachment)

        assertEquals(2, requests.size)
        assertTrue(requests[0].url.encodedPath.endsWith("/attachments"))
        assertTrue(requests[1].url.encodedPath.contains("/storage/v1/object/attachments/user-1/n1/1.png"))
    }

    @Test
    fun `서명 URL은 절대 주소로 돌려준다`() = runTest {
        val repository = repository {
            json("""{"signedURL":"/object/sign/attachments/user-1/n1/1.png?token=abc"}""")
        }

        val url = repository.signedUrl("user-1/n1/1.png")

        assertEquals(
            "https://example.supabase.co/storage/v1/object/sign/attachments/user-1/n1/1.png?token=abc",
            url,
        )
        assertTrue(requests.single().url.encodedPath.contains("/object/sign/attachments/"))
    }

    @Test
    fun `로그인 세션이 없으면 올리지 않는다`() = runTest {
        val repository = repository(tokens = FakeTokens(userId = null)) { json("{}") }

        assertFailsWith<NotesRepositoryException.NotAuthenticated> {
            repository.upload(byteArrayOf(1), "a.png", AttachmentType.IMAGE, "n1")
        }
        assertTrue(requests.isEmpty())
    }
}

/**
 * 서명 URL 캐시. 목록을 스크롤할 때마다 같은 파일의 URL을 새로 발급하면 요청이
 * 폭주한다 (iOS `AttachmentURLCache`와 같은 이유).
 */
class SignedUrlCacheTest {
    private class RecordingRepository(var url: String = "https://signed/1") : AttachmentsRepository {
        var calls = 0

        override suspend fun upload(
            bytes: ByteArray,
            fileName: String,
            type: AttachmentType,
            noteId: String,
        ): Attachment = error("쓰이지 않는다")

        override suspend fun delete(attachment: Attachment) = error("쓰이지 않는다")

        override suspend fun signedUrl(storagePath: String, expiresInSeconds: Int): String {
            calls += 1
            return "$url?path=$storagePath&n=$calls"
        }
    }

    private val now: Instant = Instant.ofEpochSecond(1_800_000_000)

    @Test
    fun `같은 경로는 한 번만 발급한다`() = runTest {
        val repository = RecordingRepository()
        val cache = SignedUrlCache(repository, clock = Clock.fixed(now, ZoneOffset.UTC))

        val first = cache.url("p/1.png")
        val second = cache.url("p/1.png")

        assertEquals(first, second)
        assertEquals(1, repository.calls)
    }

    @Test
    fun `경로가 다르면 따로 발급한다`() = runTest {
        val repository = RecordingRepository()
        val cache = SignedUrlCache(repository, clock = Clock.fixed(now, ZoneOffset.UTC))

        cache.url("p/1.png")
        cache.url("p/2.png")

        assertEquals(2, repository.calls)
    }

    /**
     * 만료 직전 URL을 그대로 주면 화면에 뜨는 순간 이미 죽어 있다.
     * 안전 여유(기본 5분)를 남기고 미리 버려야 한다.
     */
    @Test
    fun `만료가 가까우면 다시 발급한다`() = runTest {
        val repository = RecordingRepository()
        var current = now
        val cache = SignedUrlCache(
            repository = repository,
            expiresIn = Duration.ofMinutes(10),
            safetyMargin = Duration.ofMinutes(5),
            clock = object : Clock() {
                override fun instant(): Instant = current
                override fun getZone() = ZoneOffset.UTC
                override fun withZone(zone: java.time.ZoneId?): Clock = this
            },
        )

        cache.url("p/1.png")
        current = now.plus(Duration.ofMinutes(6)) // 만료 4분 전 — 여유(5분) 안쪽
        cache.url("p/1.png")

        assertEquals(2, repository.calls)
    }

    @Test
    fun `로그아웃 등으로 비우면 다시 발급한다`() = runTest {
        val repository = RecordingRepository()
        val cache = SignedUrlCache(repository, clock = Clock.fixed(now, ZoneOffset.UTC))

        cache.url("p/1.png")
        cache.clear()
        cache.url("p/1.png")

        assertEquals(2, repository.calls)
    }
}
