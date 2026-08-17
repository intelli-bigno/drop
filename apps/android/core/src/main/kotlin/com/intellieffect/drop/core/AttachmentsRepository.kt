package com.intellieffect.drop.core

import io.ktor.client.HttpClient
import io.ktor.client.request.header
import io.ktor.client.request.post
import io.ktor.client.request.setBody
import io.ktor.http.ContentType
import io.ktor.http.contentType
import java.time.Clock
import java.time.Duration
import java.time.Instant
import kotlin.coroutines.cancellation.CancellationException
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put

interface AttachmentsRepository {
    /** 파일을 스토리지에 올리고 `attachments` 행을 만든다. */
    suspend fun upload(
        bytes: ByteArray,
        fileName: String,
        type: AttachmentType,
        noteId: String,
    ): Attachment

    suspend fun delete(attachment: Attachment)

    /** 비공개 버킷이라 화면에 띄우려면 서명 URL이 필요하다. */
    suspend fun signedUrl(storagePath: String, expiresInSeconds: Int = 3600): String
}

/**
 * 첨부 파일의 저장 경로.
 *
 * **iOS·Flutter와 같은 규칙이어야 한다** — 세 앱이 같은 버킷을 보므로 규칙이 갈리면
 * 한쪽에서 올린 파일을 다른 쪽이 못 찾는다.
 *   `{user_id}/{note_id}/{고유값}.{확장자}`
 */
object StoragePath {
    fun make(
        userId: String,
        noteId: String,
        fileName: String,
        fallbackExtension: String,
        uniqueSuffix: String = uniqueSuffix(),
    ): String {
        // 파일명에서 확장자만 취한다. 이름 자체는 경로에 쓰지 않으므로 `../` 같은 값이
        // 들어와도 경로를 벗어날 수 없다.
        val extension = fileExtension(fileName) ?: fallbackExtension
        return "$userId/$noteId/$uniqueSuffix.$extension"
    }

    /** Flutter의 `${microsecondsSinceEpoch}_${salt}`와 같은 모양. */
    fun uniqueSuffix(clock: Clock = Clock.systemUTC()): String {
        val now = clock.instant()
        val microseconds = now.epochSecond * 1_000_000 + now.nano / 1_000
        return "${microseconds}_${(0..Int.MAX_VALUE).random()}"
    }

    fun fileExtension(fileName: String): String? =
        fileName.substringAfterLast('/').substringAfterLast('.', "").takeIf { it.isNotEmpty() }
}

object MimeType {
    fun forExtension(extension: String): String = when (extension.lowercase()) {
        "png" -> "image/png"
        "jpg", "jpeg" -> "image/jpeg"
        "gif" -> "image/gif"
        "webp" -> "image/webp"
        "heic" -> "image/heic"
        "m4a" -> "audio/m4a"
        "mp3" -> "audio/mpeg"
        "wav" -> "audio/wav"
        "mp4" -> "video/mp4"
        "mov" -> "video/quicktime"
        "pdf" -> "application/pdf"
        "txt" -> "text/plain"
        else -> "application/octet-stream"
    }

    fun fallbackExtension(type: AttachmentType): String = when (type) {
        AttachmentType.AUDIO -> "m4a"
        AttachmentType.IMAGE -> "png"
        AttachmentType.VIDEO -> "mp4"
        else -> "bin"
    }
}

class SupabaseAttachmentsRepository(
    private val config: DropConfiguration,
    private val client: HttpClient,
    private val tokens: AuthTokenProvider,
) : AttachmentsRepository {
    private val rest = SupabaseRest(config, client, tokens)

    override suspend fun upload(
        bytes: ByteArray,
        fileName: String,
        type: AttachmentType,
        noteId: String,
    ): Attachment {
        val userId = tokens.userId ?: throw NotesRepositoryException.NotAuthenticated

        val fallback = MimeType.fallbackExtension(type)
        val storagePath = StoragePath.make(userId, noteId, fileName, fallback)
        val mimeType = MimeType.forExtension(StoragePath.fileExtension(fileName) ?: fallback)

        rest.request {
            post(rest.storageUrl("object/$BUCKET/$storagePath")) {
                with(rest) { authorize() }
                contentType(ContentType.parse(mimeType))
                setBody(bytes)
            }
        }

        // 스토리지에는 올라갔는데 행 생성이 실패하면 고아 파일이 남는다.
        // 그 경우 올린 파일을 되돌려 두 저장소가 어긋난 채로 남지 않게 한다.
        return try {
            val created: List<AttachmentRow> = rest.postReturning(
                path = "attachments?select=*",
                body = buildJsonObject {
                    put("note_id", noteId)
                    put("type", type.raw)
                    put("storage_path", storagePath)
                    put("filename", fileName)
                    put("mime_type", mimeType)
                    put("size", bytes.size)
                },
            )
            created.firstOrNull()?.toAttachment()
                ?: throw NotesRepositoryException.Decoding("삽입된 첨부가 응답에 없습니다")
        } catch (cancellation: CancellationException) {
            throw cancellation
        } catch (error: Throwable) {
            runCatching { removeObject(storagePath) }
            throw error
        }
    }

    override suspend fun delete(attachment: Attachment) {
        rest.delete("attachments?id=eq.${attachment.id}")
        // 행이 지워졌으면 파일도 지운다. 실패해도 목록에는 이미 안 보이므로
        // 사용자 흐름을 막지 않는다.
        runCatching { removeObject(attachment.storagePath) }
    }

    override suspend fun signedUrl(storagePath: String, expiresInSeconds: Int): String {
        val response: SignedUrlResponse = rest.decode(
            rest.request {
                post(rest.storageUrl("object/sign/$BUCKET/$storagePath")) {
                    with(rest) { authorize() }
                    contentType(ContentType.Application.Json)
                    setBody(buildJsonObject { put("expiresIn", expiresInSeconds) })
                }
            },
        )
        // 응답의 signedURL은 `/object/sign/...` 로 시작하는 상대 경로다.
        return "${config.supabaseUrl}/storage/v1${response.signedUrl}"
    }

    private suspend fun removeObject(storagePath: String) {
        rest.deleteUrl(rest.storageUrl("object/$BUCKET/$storagePath"))
    }

    private companion object {
        const val BUCKET = "attachments"
    }
}

@Serializable
private data class SignedUrlResponse(@SerialName("signedURL") val signedUrl: String)

/**
 * 서명 URL 캐시.
 *
 * 비공개 버킷이라 이미지마다 서명 URL이 필요한데, 목록을 스크롤할 때마다 새로 발급하면
 * 같은 파일에 대해 요청이 폭주한다 (iOS `AttachmentURLCache`와 같은 이유).
 * 만료 [safetyMargin] 전에 미리 버려서, 화면에 뜬 순간 만료된 URL을 쓰지 않게 한다.
 */
class SignedUrlCache(
    private val repository: AttachmentsRepository,
    private val expiresIn: Duration = Duration.ofHours(1),
    private val safetyMargin: Duration = Duration.ofMinutes(5),
    private val clock: Clock = Clock.systemUTC(),
) {
    private data class Entry(val url: String, val expiresAt: Instant)

    private val mutex = Mutex()
    private val entries = mutableMapOf<String, Entry>()

    suspend fun url(storagePath: String): String {
        mutex.withLock {
            entries[storagePath]?.let { entry ->
                if (clock.instant().plus(safetyMargin).isBefore(entry.expiresAt)) return entry.url
                entries.remove(storagePath)
            }
        }

        val url = repository.signedUrl(storagePath, expiresIn.seconds.toInt())
        mutex.withLock {
            entries[storagePath] = Entry(url, clock.instant().plus(expiresIn))
        }
        return url
    }

    suspend fun clear() = mutex.withLock { entries.clear() }
}
