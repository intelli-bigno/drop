package com.intellieffect.drop.core

import java.time.Instant
import kotlin.coroutines.cancellation.CancellationException
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertFalse
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue
import kotlinx.coroutines.test.runTest

/**
 * iOS `NotesStoreTests`의 이식본.
 * 목록·선택·필터 상태를 하나로 합친 것 (iOS `NotesStore`와 같은 의미).
 */
class NotesStoreTest {
    private fun store(notes: List<Note> = emptyList()): Pair<NotesStore, InMemoryNotesRepository> {
        val repository = InMemoryNotesRepository(notes)
        return NotesStore(repository) to repository
    }

    private fun note(
        id: String,
        content: String = "",
        createdOffsetSeconds: Long = 0,
        archived: Boolean = false,
        trashed: Boolean = false,
        pinned: Boolean = false,
        hasLink: Boolean = false,
        tags: List<String> = emptyList(),
    ) = Note(
        id = id,
        displayId = 1,
        content = content,
        tags = tags.map { Tag(id = it, name = it, createdAt = Instant.EPOCH) },
        createdAt = Instant.ofEpochSecond(1_700_000_000 + createdOffsetSeconds),
        updatedAt = Instant.EPOCH,
        source = NoteSource.MOBILE,
        archivedAt = if (archived) Instant.EPOCH else null,
        deletedAt = if (trashed) Instant.EPOCH else null,
        hasLink = hasLink,
        isPinned = pinned,
    )

    @Test
    fun `불러오면 목록이 채워진다`() = runTest {
        val (store, _) = store(listOf(note("a"), note("b")))

        store.load()

        assertEquals(2, store.state.value.visibleNotes.size)
        assertFalse(store.state.value.isLoading)
    }

    @Test
    fun `실패하면 오류를 노출하고 목록은 비운다`() = runTest {
        val (store, repository) = store()
        repository.loadError = NotesRepositoryException.Network("끊김")

        store.load()

        assertNotNull(store.state.value.errorMessage)
        assertTrue(store.state.value.visibleNotes.isEmpty())
    }

    /**
     * 당겨서 새로고침은 손을 떼는 순간 취소된다. 취소는 장애가 아니므로
     * 오류창을 띄우지도, 이미 보고 있던 목록을 지우지도 않아야 한다.
     * (취소 자체는 구조적 동시성을 지키기 위해 다시 던진다 — 그러나 상태는 건드리지 않는다.)
     */
    @Test
    fun `취소된 로드는 오류가 아니다`() = runTest {
        val (store, repository) = store(listOf(note("a"), note("b")))
        store.load()

        repository.loadError = CancellationException("당겨서 새로고침 취소")
        assertFailsWith<CancellationException> { store.load() }

        assertNull(store.state.value.errorMessage)
        assertEquals(2, store.state.value.visibleNotes.size)
        assertFalse(store.state.value.isLoading)
    }

    /** 보관·휴지통 노트도 함께 받아 화면에서 거른다 (iOS와 같은 구조). */
    @Test
    fun `뷰 모드가 목록을 가른다`() = runTest {
        val (store, _) = store(
            listOf(note("활성"), note("보관", archived = true), note("휴지통", trashed = true)),
        )
        store.load()

        assertEquals(listOf("활성"), store.state.value.visibleNotes.map { it.id })

        store.setViewMode(NoteViewMode.ARCHIVED)
        assertEquals(listOf("보관"), store.state.value.visibleNotes.map { it.id })

        store.setViewMode(NoteViewMode.TRASH)
        assertEquals(listOf("휴지통"), store.state.value.visibleNotes.map { it.id })
    }

    @Test
    fun `카테고리 필터가 함께 걸린다`() = runTest {
        val (store, _) = store(listOf(note("링크", hasLink = true), note("보통")))
        store.load()

        store.setCategory(NoteCategory.LINKS)

        assertEquals(listOf("링크"), store.state.value.visibleNotes.map { it.id })
    }

    @Test
    fun `태그 필터는 선택한 태그를 가진 노트만 남긴다`() = runTest {
        val (store, _) = store(listOf(note("일", tags = listOf("work")), note("잡", tags = listOf("etc"))))
        store.load()

        store.setSelectedTagId("work")

        assertEquals(listOf("일"), store.state.value.visibleNotes.map { it.id })
    }

    @Test
    fun `검색어는 본문에 걸린다`() = runTest {
        val (store, _) = store(listOf(note("a", content = "회의 준비"), note("b", content = "장보기")))
        store.load()

        store.setSearchText("회의")

        assertEquals(listOf("a"), store.state.value.visibleNotes.map { it.id })
    }

    /** 새 노트는 저장을 기다리지 않고 목록에 먼저 들어간다. */
    @Test
    fun `작성한 노트가 목록 맨 앞에 즉시 나타난다`() = runTest {
        val (store, _) = store(listOf(note("기존")))
        store.load()

        store.create("새 노트")

        assertEquals("새 노트", store.state.value.visibleNotes.first().content)
        assertEquals(2, store.state.value.visibleNotes.size)
    }

    /**
     * 실패하면 끼워 넣은 노트를 걷어내야 한다. 안 그러면 새로고침 전까지
     * 저장되지도 않은 노트가 목록에 남아 있게 된다.
     */
    @Test
    fun `작성이 실패하면 끼워 넣은 노트를 되돌린다`() = runTest {
        val (store, repository) = store(listOf(note("기존")))
        store.load()
        repository.createError = NotesRepositoryException.Rejected("거절")

        store.create("새 노트")

        assertEquals(listOf("기존"), store.state.value.visibleNotes.map { it.id })
        assertNotNull(store.state.value.errorMessage)
    }

    @Test
    fun `휴지통으로 보내면 활성 목록에서 사라진다`() = runTest {
        val (store, _) = store(listOf(note("a"), note("b")))
        store.load()

        store.moveToTrash("a")

        assertEquals(listOf("b"), store.state.value.visibleNotes.map { it.id })
    }

    @Test
    fun `휴지통에서 되살리면 활성 목록으로 돌아온다`() = runTest {
        val (store, _) = store(listOf(note("a", trashed = true)))
        store.load()

        store.restore("a")

        assertEquals(listOf("a"), store.state.value.visibleNotes.map { it.id })
    }

    /** Rule B (BRU-115): 복원은 받은편지함으로 되돌리기다. */
    @Test
    fun `보관한 노트를 휴지통에 넣었다 복원하면 활성 목록으로 온다`() = runTest {
        val (store, _) = store(listOf(note("a", archived = true)))
        store.load()

        store.moveToTrash("a")
        store.setViewMode(NoteViewMode.TRASH)
        assertEquals(listOf("a"), store.state.value.visibleNotes.map { it.id })

        store.restore("a")

        store.setViewMode(NoteViewMode.ACTIVE)
        assertEquals(listOf("a"), store.state.value.visibleNotes.map { it.id })
        store.setViewMode(NoteViewMode.ARCHIVED)
        assertTrue(store.state.value.visibleNotes.isEmpty())
    }

    /** 예전 데스크톱이 archived_at을 남긴 이중 플래그 행도 복원하면 활성이다. */
    @Test
    fun `휴지통에 남은 보관 흔적도 복원하면 지워진다`() = runTest {
        val (store, _) = store(listOf(note("a", archived = true, trashed = true)))
        store.load()

        store.restore("a")

        store.setViewMode(NoteViewMode.ACTIVE)
        assertEquals(listOf("a"), store.state.value.visibleNotes.map { it.id })
        store.setViewMode(NoteViewMode.ARCHIVED)
        assertTrue(store.state.value.visibleNotes.isEmpty())
    }

    @Test
    fun `보관하면 활성 목록에서 빠지고 보관함에 들어간다`() = runTest {
        val (store, _) = store(listOf(note("a")))
        store.load()

        store.archive("a")

        assertTrue(store.state.value.visibleNotes.isEmpty())
        store.setViewMode(NoteViewMode.ARCHIVED)
        assertEquals(listOf("a"), store.state.value.visibleNotes.map { it.id })
    }

    @Test
    fun `보관을 풀면 활성 목록으로 돌아온다`() = runTest {
        val (store, _) = store(listOf(note("a", archived = true)))
        store.load()

        store.unarchive("a")

        assertEquals(listOf("a"), store.state.value.visibleNotes.map { it.id })
    }

    @Test
    fun `삭제가 실패하면 노트가 목록으로 돌아온다`() = runTest {
        val (store, repository) = store(listOf(note("a")))
        store.load()
        repository.mutationError = NotesRepositoryException.Network("끊김")

        store.moveToTrash("a")

        assertEquals(listOf("a"), store.state.value.visibleNotes.map { it.id })
        assertNotNull(store.state.value.errorMessage)
    }

    @Test
    fun `영구 삭제하면 목록에서 완전히 사라진다`() = runTest {
        val (store, _) = store(listOf(note("a", trashed = true), note("b", trashed = true)))
        store.load()
        store.setViewMode(NoteViewMode.TRASH)

        store.deletePermanently("a")

        assertEquals(listOf("b"), store.state.value.visibleNotes.map { it.id })
    }

    @Test
    fun `영구 삭제가 실패하면 목록을 되돌린다`() = runTest {
        val (store, repository) = store(listOf(note("a", trashed = true)))
        store.load()
        store.setViewMode(NoteViewMode.TRASH)
        repository.mutationError = NotesRepositoryException.NotAuthenticated

        store.deletePermanently("a")

        assertEquals(listOf("a"), store.state.value.visibleNotes.map { it.id })
        assertNotNull(store.state.value.errorMessage)
    }

    @Test
    fun `선택 모드에서 여러 노트를 골라 한 번에 버린다`() = runTest {
        val (store, _) = store(listOf(note("a"), note("b"), note("c")))
        store.load()

        store.toggleSelection("a")
        store.toggleSelection("c")
        assertEquals(setOf("a", "c"), store.state.value.selectedIds)
        assertTrue(store.state.value.isSelecting)

        store.trashSelected()

        assertEquals(listOf("b"), store.state.value.visibleNotes.map { it.id })
        // 일괄 처리가 끝나면 선택 모드에서 빠져나와야 한다 —
        // 선택이 남아 있으면 다음 탭이 엉뚱한 노트에 걸린다.
        assertTrue(store.state.value.selectedIds.isEmpty())
        assertFalse(store.state.value.isSelecting)
    }

    @Test
    fun `선택을 다시 누르면 해제된다`() = runTest {
        val (store, _) = store(listOf(note("a")))
        store.load()

        store.toggleSelection("a")
        store.toggleSelection("a")

        assertTrue(store.state.value.selectedIds.isEmpty())
        assertFalse(store.state.value.isSelecting)
    }

    @Test
    fun `고정하면 목록 맨 위로 올라간다`() = runTest {
        val (store, _) = store(
            listOf(note("a", createdOffsetSeconds = 100), note("b", createdOffsetSeconds = 0)),
        )
        store.load()

        store.setPinned("b", true)

        assertEquals(listOf("b", "a"), store.state.value.visibleNotes.map { it.id })
    }

    @Test
    fun `본문을 고치면 목록에 바로 반영된다`() = runTest {
        val (store, _) = store(listOf(note("a", content = "예전")))
        store.load()

        store.update("a", "새 내용")

        assertEquals("새 내용", store.state.value.visibleNotes.first().content)
    }

    /** 필터 칩은 지금 목록에 실제로 붙어 있는 태그만 보여 준다. */
    @Test
    fun `보이는 태그 목록은 중복 없이 모인다`() = runTest {
        val (store, _) = store(
            listOf(
                note("a", tags = listOf("work", "life")),
                note("b", tags = listOf("work")),
            ),
        )
        store.load()

        assertEquals(setOf("work", "life"), store.state.value.availableTags.map { it.id }.toSet())
        assertEquals(2, store.state.value.availableTags.size)
    }

    @Test
    fun `오류는 닫으면 사라진다`() = runTest {
        val (store, repository) = store()
        repository.loadError = NotesRepositoryException.Network("끊김")
        store.load()
        assertNotNull(store.state.value.errorMessage)

        store.dismissError()

        assertNull(store.state.value.errorMessage)
    }
}
