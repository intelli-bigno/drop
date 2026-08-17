package com.intellieffect.drop.core

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertNull
import kotlin.test.assertTrue
import kotlinx.coroutines.test.runTest

/**
 * 공유로 들어온 것을 담는 순서와 실패 시 남는 것.
 *
 * 실기에서 실제로 겪은 것을 그대로 옮겼다: 파일을 읽지 못했을 때 조용히 성공으로
 * 보고하고 빈 노트만 남는 문제 (BRU-41 실측).
 */
class SharedCaptureTest {
    private class FakeAttachments : AttachmentsRepository {
        val uploaded = mutableListOf<String>()
        var uploadError: Throwable? = null

        override suspend fun upload(
            bytes: ByteArray,
            fileName: String,
            type: AttachmentType,
            noteId: String,
        ): Attachment {
            uploadError?.let { throw it }
            uploaded += fileName
            return Attachment(
                id = "a${uploaded.size}",
                noteId = noteId,
                type = type,
                storagePath = "u/$noteId/$fileName",
                createdAt = java.time.Instant.EPOCH,
            )
        }

        override suspend fun delete(attachment: Attachment) = Unit

        override suspend fun signedUrl(storagePath: String, expiresInSeconds: Int): String =
            "https://signed/$storagePath"
    }

    private fun capture(
        notes: InMemoryNotesRepository = InMemoryNotesRepository(),
        attachments: FakeAttachments = FakeAttachments(),
    ) = Triple(SharedCapture(notes, attachments), notes, attachments)

    private fun file(name: String = "photo.png", type: AttachmentType = AttachmentType.IMAGE) =
        SharedCapture.SharedFile(name, type, byteArrayOf(1, 2, 3))

    @Test
    fun `제목과 본문을 두 줄로 담는다`() = runTest {
        val (capture, notes, _) = capture()

        val note = capture.capture(
            SharedCapture.Payload(text = "https://example.com", subject = "예시 제목"),
        )

        assertEquals("예시 제목\nhttps://example.com", note?.content)
        assertEquals(1, notes.loadNotes().size)
    }

    /** 제목과 본문이 같은 문자열로 오는 앱이 있다 — 두 번 적지 않는다. */
    @Test
    fun `제목과 본문이 같으면 한 번만 담는다`() = runTest {
        val (capture, _, _) = capture()

        val note = capture.capture(
            SharedCapture.Payload(text = "같은 값", subject = "같은 값"),
        )

        assertEquals("같은 값", note?.content)
    }

    @Test
    fun `텍스트 없이 파일만 오면 파일 이름을 본문으로 쓴다`() = runTest {
        val (capture, _, attachments) = capture()

        val note = capture.capture(SharedCapture.Payload(files = listOf(file("여행.png"))))

        assertEquals("여행.png", note?.content)
        assertEquals(listOf("여행.png"), attachments.uploaded)
    }

    @Test
    fun `담을 것이 아무것도 없으면 노트를 만들지 않는다`() = runTest {
        val (capture, notes, _) = capture()

        assertNull(capture.capture(SharedCapture.Payload(text = "   ", subject = null)))
        assertTrue(notes.loadNotes().isEmpty())
    }

    /**
     * 첨부를 담으려고 공유했는데 업로드가 실패하면, 파일 없는 빈 노트만 남는다.
     * 사용자는 실패한 줄도 모르고 쓸모없는 노트를 손으로 지워야 한다 — 되돌려야 한다.
     */
    @Test
    fun `업로드가 실패하면 만든 노트를 되돌린다`() = runTest {
        val (capture, notes, attachments) = capture()
        attachments.uploadError = NotesRepositoryException.Rejected("용량 초과")

        assertFailsWith<NotesRepositoryException.Rejected> {
            capture.capture(SharedCapture.Payload(text = "사진 공유", files = listOf(file())))
        }

        assertTrue(notes.loadNotes().isEmpty(), "실패했으면 노트가 남아 있어서는 안 된다")
    }

    @Test
    fun `여러 파일을 모두 담는다`() = runTest {
        val (capture, _, attachments) = capture()

        capture.capture(
            SharedCapture.Payload(
                files = listOf(file("1.png"), file("2.mp4", AttachmentType.VIDEO)),
            ),
        )

        assertEquals(listOf("1.png", "2.mp4"), attachments.uploaded)
    }

    /** 첨부가 붙었으면 카테고리 플래그도 세워야 "미디어" 탭에서 보인다. */
    @Test
    fun `미디어 첨부는 카테고리 플래그를 세운다`() = runTest {
        val (capture, notes, _) = capture()

        val note = capture.capture(SharedCapture.Payload(files = listOf(file())))

        val saved = notes.loadNotes().first { it.id == note?.id }
        assertTrue(saved.hasMedia)
        assertTrue(saved.matches(NoteCategory.MEDIA))
    }
}
