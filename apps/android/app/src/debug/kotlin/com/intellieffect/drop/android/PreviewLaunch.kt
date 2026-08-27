package com.intellieffect.drop.android

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Color
import android.net.Uri
import com.intellieffect.drop.core.Attachment
import com.intellieffect.drop.core.AttachmentType
import com.intellieffect.drop.core.AttachmentsRepository
import com.intellieffect.drop.core.AuthGateway
import com.intellieffect.drop.core.AuthTokenProvider
import com.intellieffect.drop.core.DropConfiguration
import com.intellieffect.drop.core.DropUser
import com.intellieffect.drop.core.GoogleIdentity
import com.intellieffect.drop.core.InMemoryCommentsRepository
import com.intellieffect.drop.core.InMemoryNotesRepository
import com.intellieffect.drop.core.InMemoryTagsRepository
import com.intellieffect.drop.core.MimeType
import com.intellieffect.drop.core.Note
import com.intellieffect.drop.core.NoteComment
import com.intellieffect.drop.core.NoteSource
import com.intellieffect.drop.core.Session
import com.intellieffect.drop.core.StoragePath
import com.intellieffect.drop.core.Tag
import java.io.File
import java.time.Instant
import java.util.UUID
import kotlin.math.abs

/**
 * 자격증명 없이 화면·위젯을 띄워 보기 위한 디버그 전용 경로 (BRU-136).
 * iOS `PreviewLaunch.swift`(`-dropPreview`)와 같은 자리이고 표본도 같다.
 *
 * `make android-preview`(= `-PdropPreview=true`)로 빌드하면 인증을 건너뛰고 인메모리
 * 데이터를 쓴다. 이 파일은 `src/debug`에만 있어 릴리스 APK에는 들어가지 않는다.
 *
 * 왜 실기기에 필요한가: Google 로그인은 디버그 SHA-1 미등록으로 막혀 있고(BRU-30),
 * README의 로컬 Supabase 우회는 `10.0.2.2`를 보는 **에뮬레이터 전용**이다.
 * UI만 고치려는 사람도 리모트(대표 개인) Supabase에 붙어야 했다.
 */
object PreviewLaunch {
    fun makeContainer(context: Context): DropContainer {
        val notes = InMemoryNotesRepository(sampleNotes())
        return DropContainer(
            // 검증만 통과하는 값. 프리뷰는 네트워크에 나가지 않는다.
            configuration = DropConfiguration(
                supabaseUrl = "http://preview.invalid",
                supabaseAnonKey = "preview",
                googleWebClientId = "preview",
            ),
            authGateway = PreviewAuthGateway,
            notesRepository = notes,
            tagsRepository = InMemoryTagsRepository(notes),
            commentsRepository = InMemoryCommentsRepository(sampleComments()),
            attachmentsRepository = PreviewAttachmentsRepository(context, notes),
        )
    }

    /**
     * 댓글 표본. 뱃지가 붙는 노트(1·2)와 하나도 없는 노트를 함께 둔다 —
     * 0이면 뱃지를 그리지 않는다는 규칙을 눈으로 확인하기 위한 것이다.
     */
    private fun sampleComments(): List<NoteComment> {
        val now = Instant.now()
        fun comment(id: String, note: String, body: String, minutesAgo: Long): NoteComment {
            val at = now.minusSeconds(60 * minutesAgo)
            return NoteComment(id = id, noteId = note, body = body, createdAt = at, updatedAt = at)
        }
        return listOf(
            comment("c1", "1", "M3까지는 왔는데 위젯이 아직 남았다.", minutesAgo = 90),
            comment("c2", "1", "위젯은 BRU-68에서 따로 본다.", minutesAgo = 40),
            comment("c3", "1", "확인.", minutesAgo = 5),
            comment("c4", "2", "원두는 지난번 것으로.", minutesAgo = 30),
        )
    }

    private fun sampleNotes(): List<Note> {
        val now = Instant.now()
        fun tag(name: String) = Tag(id = name, name = name, createdAt = now)
        fun ago(seconds: Long): Instant = now.minusSeconds(seconds)

        return listOf(
            Note(
                id = "1", displayId = 12,
                content = "Android 네이티브 전환 — 홈 화면까지 올라왔다.",
                tags = listOf(tag("개발")),
                createdAt = ago(120), updatedAt = now, source = NoteSource.MOBILE,
                isPinned = true, pinnedAt = now, priority = 3,
            ),
            Note(
                id = "2", displayId = 11,
                content = "장보기: 우유, 커피 원두, 사과",
                tags = listOf(tag("생활")),
                createdAt = ago(3600), updatedAt = now, source = NoteSource.DESKTOP,
                priority = 2,
            ),
            // 계층 표본 (BRU-60). 답글은 자기 시각이 아니라 부모의 섹션에 붙어야 한다 —
            // 아래 두 답글은 부모("장보기", 1시간 전)보다 나중에 쓰였다.
            Note(
                id = "2-1", displayId = 17,
                content = "원두는 지난번 것으로",
                parentId = "2",
                createdAt = ago(1800), updatedAt = now, source = NoteSource.DESKTOP,
            ),
            Note(
                id = "2-1-1", displayId = 18,
                content = "품절이면 다른 것도 괜찮다",
                parentId = "2-1",
                createdAt = ago(900), updatedAt = now, source = NoteSource.DESKTOP,
            ),
            // 부모가 보관함에 있어 최상위로 올라오는 답글. 화살표 표시가 붙어야 한다.
            Note(
                id = "4-1", displayId = 19,
                content = "회고에서 나온 후속 — 부모는 보관함에 있다",
                parentId = "4",
                createdAt = ago(7200), updatedAt = now, source = NoteSource.DESKTOP,
            ),
            // 한 줄로 줄인 뒤에도 긴 본문이 줄을 밀지 않는지 눈으로 보기 위한 표본.
            Note(
                id = "6", displayId = 14,
                content = "긴 본문은 한 줄에서 잘려야 한다 — 목록은 훑는 자리이고 다 읽는 자리는 컴포저다. " +
                    "이 문장이 두 줄로 내려가면 한 화면에 들어오는 노트 수가 다시 줄어든다.",
                tags = listOf(tag("설계"), tag("android"), tag("bru-136")),
                createdAt = ago(5400), updatedAt = now, source = NoteSource.DESKTOP,
                priority = 1,
            ),
            // 마크다운 표본 (BRU-37). 목록에서는 기호가 걷힌 한 줄로 보이고,
            // 뷰어에서 제목·목록·체크박스·코드·인용·링크가 서야 한다.
            Note(
                id = "9", displayId = 20,
                content = """
                    # 이번 주 정리

                    **굵게**와 *기울임*, 그리고 `인라인 코드`.

                    - [x] 파서를 core에 두기
                    - [ ] 뷰어 붙이기
                      - 목록 안의 목록
                    - [ ] 편집기 툴바

                    1. 첫째
                    2. 둘째

                    > 저장 형식은 평문 마크다운 그대로다.

                    ```kotlin
                    val document = MarkdownParser().parse(note.content)
                    ```

                    ---

                    [이슈 보기](https://linear.app/intellieffect/issue/BRU-37)
                """.trimIndent(),
                tags = listOf(tag("설계")),
                createdAt = ago(300), updatedAt = now, source = NoteSource.DESKTOP,
                priority = 2,
            ),
            Note(
                id = "7", displayId = 15,
                content = "어제 적어 둔 메모",
                createdAt = ago(100_000), updatedAt = now, source = NoteSource.MOBILE,
            ),
            Note(
                id = "8", displayId = 16,
                content = "사흘 전 링크 https://example.com/read-later",
                createdAt = ago(260_000), updatedAt = now, source = NoteSource.WEB,
                hasLink = true,
            ),
            Note(
                id = "5", displayId = 13,
                content = "제주 사진 몇 장",
                attachments = (1..3).map { index ->
                    Attachment(
                        id = "img$index", noteId = "5", type = AttachmentType.IMAGE,
                        storagePath = "u/5/img$index.png", filename = "img$index.png",
                        mimeType = "image/png", size = 240_000, createdAt = now,
                    )
                },
                tags = listOf(tag("사진")),
                createdAt = ago(600), updatedAt = now, source = NoteSource.MOBILE,
                hasMedia = true,
            ),
            Note(
                id = "3", displayId = 10,
                content = "회의 녹음",
                attachments = listOf(
                    Attachment(
                        id = "a1", noteId = "3", type = AttachmentType.AUDIO, storagePath = "u/3/a1.m4a",
                        filename = "a1.m4a", mimeType = "audio/m4a", size = 1_536_000, createdAt = now,
                    ),
                ),
                createdAt = ago(90_000), updatedAt = now, source = NoteSource.MCP,
                hasMedia = true,
            ),
            Note(
                id = "4", displayId = 9,
                content = "보관해 둔 지난 분기 회고",
                createdAt = ago(400_000), updatedAt = now, source = NoteSource.WEB,
                archivedAt = ago(100_000),
            ),
            Note(
                id = "10", displayId = 8,
                content = "휴지통에 있는 메모",
                createdAt = ago(500_000), updatedAt = now, source = NoteSource.MOBILE,
                deletedAt = ago(50_000),
            ),
        )
    }
}

/**
 * 항상 로그인돼 있는 게이트웨이. `restore()`가 세션을 돌려주므로 `AuthStore`가
 * 첫 화면에서 `SignedIn`으로 넘어간다 — `MainActivity`의 게이트를 고칠 필요가 없다.
 */
object PreviewAuthGateway : AuthGateway, AuthTokenProvider {
    private val session = Session(
        accessToken = "preview-access-token",
        refreshToken = "preview-refresh-token",
        // 2100-01-01. 프리뷰에서 만료 판정이 돌 일은 없지만 값은 먼 미래여야 한다.
        expiresAt = Instant.ofEpochSecond(4_102_444_800),
        user = DropUser(id = "preview-user", email = "preview@drop.local"),
    )

    override suspend fun restore(): Session = session
    override suspend fun signIn(identity: GoogleIdentity): Session = session
    override suspend fun signOut() = Unit
    override suspend fun accessToken(): String = session.accessToken
    override val userId: String get() = session.user.id
}

/**
 * 첨부를 앱 캐시 디렉토리에 두고 `file://` URL을 돌려준다.
 *
 * 표본 첨부(`u/5/img1.png` 같은 경로)는 실제 파일이 없으므로 처음 요청될 때 색만
 * 다른 단색 PNG를 만든다 — 그림 내용은 중요하지 않고, 썸네일 경로가 실제로
 * 그려지는지가 중요하다 (iOS `PreviewLaunch.attachmentURL`과 같은 판단).
 */
class PreviewAttachmentsRepository(
    context: Context,
    private val notes: InMemoryNotesRepository,
) : AttachmentsRepository {
    private val directory = File(context.cacheDir, "preview-attachments").apply { mkdirs() }

    override suspend fun upload(
        bytes: ByteArray,
        fileName: String,
        type: AttachmentType,
        noteId: String,
    ): Attachment {
        val fallback = MimeType.fallbackExtension(type)
        val storagePath = StoragePath.make(PreviewAuthGateway.userId, noteId, fileName, fallback)
        fileFor(storagePath).writeBytes(bytes)

        val attachment = Attachment(
            id = UUID.randomUUID().toString(),
            noteId = noteId,
            type = type,
            storagePath = storagePath,
            filename = fileName,
            mimeType = MimeType.forExtension(StoragePath.fileExtension(fileName) ?: fallback),
            size = bytes.size.toLong(),
            createdAt = Instant.now(),
        )
        notes.replace(noteId) { it.copy(attachments = it.attachments + attachment) }
        return attachment
    }

    override suspend fun delete(attachment: Attachment) {
        notes.replaceAll { note ->
            note.copy(attachments = note.attachments.filterNot { it.id == attachment.id })
        }
        fileFor(attachment.storagePath).delete()
    }

    override suspend fun signedUrl(storagePath: String, expiresInSeconds: Int): String {
        val file = fileFor(storagePath)
        if (!file.exists()) file.writeBytes(solidPng(seed = storagePath))
        return Uri.fromFile(file).toString()
    }

    private fun fileFor(storagePath: String) = File(directory, storagePath.replace('/', '_'))

    private fun solidPng(seed: String): ByteArray {
        val hue = (abs(seed.hashCode()) % 100) * 3.6f
        val bitmap = Bitmap.createBitmap(240, 240, Bitmap.Config.ARGB_8888)
        bitmap.eraseColor(Color.HSVToColor(floatArrayOf(hue, 0.5f, 0.9f)))
        return java.io.ByteArrayOutputStream().use { out ->
            bitmap.compress(Bitmap.CompressFormat.PNG, 100, out)
            out.toByteArray()
        }
    }
}
