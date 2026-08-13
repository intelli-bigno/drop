package com.intellieffect.drop.core

import java.time.Instant
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

/**
 * iOS `NoteAssemblerTests`의 이식본.
 *
 * 목록 조회는 notes / attachments / note_tags 세 쿼리 결과를 합쳐 만든다.
 * 합치는 규칙만 떼어내면 네트워크 없이 검증할 수 있다 — 실제 버그가 나는 곳도 여기다.
 */
class NoteAssemblerTest {
    private val now: Instant = Instant.ofEpochSecond(1_770_000_000)

    private fun note(
        id: String,
        pinned: Boolean = false,
        pinnedAt: Instant? = null,
        createdOffsetSeconds: Long = 0,
    ) = Note(
        id = id,
        displayId = 1,
        content = "",
        createdAt = now.plusSeconds(createdOffsetSeconds),
        updatedAt = now,
        source = NoteSource.MOBILE,
        isPinned = pinned,
        pinnedAt = pinnedAt,
    )

    private fun attachment(id: String, noteId: String) = Attachment(
        id = id,
        noteId = noteId,
        type = AttachmentType.IMAGE,
        storagePath = "p/$id",
        createdAt = now,
    )

    private fun tag(id: String, name: String) = Tag(id = id, name = name, createdAt = now)

    @Test
    fun `첨부와 태그를 노트별로 붙인다`() {
        val assembled = NoteAssembler.assemble(
            notes = listOf(note("n1"), note("n2")),
            attachments = listOf(attachment("a1", "n1"), attachment("a2", "n1")),
            tagsByNoteId = mapOf("n2" to listOf(tag("t1", "일"))),
        )

        assertEquals(listOf("a1", "a2"), assembled[0].attachments.map { it.id })
        assertTrue(assembled[0].tags.isEmpty())
        assertTrue(assembled[1].attachments.isEmpty())
        assertEquals(listOf("일"), assembled[1].tags.map { it.name })
    }

    /** 삭제된 노트의 첨부가 뒤늦게 딸려오는 경우가 있다. 주인 없는 첨부는 버린다. */
    @Test
    fun `주인이 없는 첨부는 버린다`() {
        val assembled = NoteAssembler.assemble(
            notes = listOf(note("n1")),
            attachments = listOf(attachment("a1", "n1"), attachment("a9", "없는노트")),
            tagsByNoteId = emptyMap(),
        )

        assertEquals(1, assembled.size)
        assertEquals(listOf("a1"), assembled[0].attachments.map { it.id })
    }

    @Test
    fun `입력 순서를 그대로 유지한다`() {
        val assembled = NoteAssembler.assemble(
            notes = listOf(note("c"), note("a"), note("b")),
            attachments = emptyList(),
            tagsByNoteId = emptyMap(),
        )

        assertEquals(listOf("c", "a", "b"), assembled.map { it.id })
    }

    /**
     * 정렬 규칙: 고정 먼저 → 고정 시각 최신순 → 생성 시각 최신순.
     * 서버 정렬과 같은 규칙을 클라이언트에도 두어야 낙관적 갱신으로 끼워 넣은
     * 노트가 새로고침 전후로 자리를 바꾸지 않는다.
     */
    @Test
    fun `고정된 노트가 위로, 그 안에서는 최신순`() {
        val old = note("old", createdOffsetSeconds = -100)
        val new = note("new", createdOffsetSeconds = 100)
        val pinnedEarlier = note("p1", pinned = true, pinnedAt = now.minusSeconds(50))
        val pinnedLater = note("p2", pinned = true, pinnedAt = now)

        val sorted = NoteAssembler.sorted(listOf(old, new, pinnedEarlier, pinnedLater))

        assertEquals(listOf("p2", "p1", "new", "old"), sorted.map { it.id })
    }

    /** 고정 시각이 없는 오래된 데이터가 섞여 있어도 정렬이 무너지면 안 된다. */
    @Test
    fun `고정 시각이 없는 고정 노트도 고정 묶음에 남는다`() {
        val pinnedNoDate = note("p0", pinned = true, pinnedAt = null)
        val plain = note("n", createdOffsetSeconds = 1000)

        val sorted = NoteAssembler.sorted(listOf(plain, pinnedNoDate))

        assertEquals(listOf("p0", "n"), sorted.map { it.id })
    }
}
