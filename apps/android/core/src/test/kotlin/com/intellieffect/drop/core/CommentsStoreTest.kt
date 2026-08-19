package com.intellieffect.drop.core

import java.time.Instant
import kotlin.coroutines.cancellation.CancellationException
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue
import kotlinx.coroutines.test.runTest

/**
 * iOS `CommentsStoreTests`의 이식본 (BRU-64 → BRU-86).
 *
 * 여기서 못 박는 규칙은 `NotesStore`와 같다(BRU-51): 로드 실패는 보고 있던 목록을
 * 지우지 않고, 취소는 오류가 아니며, 작성·삭제는 낙관적으로 먼저 반영하고 실패하면 되돌린다.
 */
class CommentsStoreTest {
    private fun comment(id: String, noteId: String, body: String, secondsAgo: Long) = NoteComment(
        id = id,
        noteId = noteId,
        body = body,
        createdAt = Instant.ofEpochSecond(1_800_000_000 - secondsAgo),
        updatedAt = Instant.ofEpochSecond(1_800_000_000 - secondsAgo),
    )

    private fun store(comments: List<NoteComment> = emptyList()):
        Pair<CommentsStore, InMemoryCommentsRepository> {
        val repository = InMemoryCommentsRepository(comments)
        return CommentsStore(repository) to repository
    }

    @Test
    fun `노트의 댓글을 오래된 순으로 불러온다`() = runTest {
        val (store, _) = store(
            listOf(
                comment("c2", "n1", "나중", secondsAgo = 10),
                comment("c1", "n1", "먼저", secondsAgo = 100),
            ),
        )

        store.load("n1")

        assertEquals(listOf("먼저", "나중"), store.state.value.comments("n1").map { it.body })
    }

    @Test
    fun `다른 노트의 댓글은 섞이지 않는다`() = runTest {
        val (store, _) = store(
            listOf(
                comment("c1", "n1", "이 노트", secondsAgo = 10),
                comment("c2", "n2", "저 노트", secondsAgo = 10),
            ),
        )

        store.load("n1")

        assertEquals(listOf("이 노트"), store.state.value.comments("n1").map { it.body })
    }

    /** 열어 보지 않은 노트는 0이고, 화면은 0이면 뱃지를 그리지 않는다. */
    @Test
    fun `모르는 노트의 댓글 수는 0이다`() = runTest {
        val (store, _) = store()

        assertEquals(0, store.state.value.count("없는-노트"))
        assertTrue(store.state.value.comments("없는-노트").isEmpty())
    }

    /** 목록 화면은 노트마다 조회하지 않고 개수만 한 번에 받는다. */
    @Test
    fun `개수는 한 번의 호출로 전부 채운다`() = runTest {
        val (store, repository) = store(
            listOf(
                comment("c1", "n1", "하나", secondsAgo = 30),
                comment("c2", "n1", "둘", secondsAgo = 20),
                comment("c3", "n2", "셋", secondsAgo = 10),
            ),
        )

        store.loadCounts()

        assertEquals(2, store.state.value.count("n1"))
        assertEquals(1, store.state.value.count("n2"))
        assertEquals(1, repository.countCalls)
    }

    @Test
    fun `불러오기에 실패하면 오류를 노출한다`() = runTest {
        val (store, repository) = store()
        repository.loadError = NotesRepositoryException.Network("끊김")

        store.load("n1")

        assertEquals("네트워크에 연결하지 못했습니다.", store.state.value.errorMessage)
    }

    /**
     * 실패한 것은 "새 목록을 받아오는 일"이지 이미 받아 둔 목록이 아니다 (BRU-51).
     * 지워 버리면 잠깐의 네트워크 장애로 읽고 있던 대화가 사라진다.
     */
    @Test
    fun `불러오기에 실패해도 이미 받아 둔 댓글은 남는다`() = runTest {
        val (store, repository) = store(listOf(comment("c1", "n1", "먼저", secondsAgo = 10)))
        store.load("n1")

        repository.loadError = NotesRepositoryException.Network("끊김")
        store.load("n1")

        assertEquals(listOf("먼저"), store.state.value.comments("n1").map { it.body })
    }

    /** 취소는 실패가 아니다 — 오류 문구도 목록도 건드리지 않는다. */
    @Test
    fun `취소는 오류가 아니다`() = runTest {
        val (store, repository) = store(listOf(comment("c1", "n1", "먼저", secondsAgo = 10)))
        store.load("n1")

        repository.loadError = CancellationException("화면을 벗어남")
        assertFailsWith<CancellationException> { store.load("n1") }

        assertNull(store.state.value.errorMessage)
        assertEquals(listOf("먼저"), store.state.value.comments("n1").map { it.body })
    }

    @Test
    fun `댓글을 쓰면 목록과 개수가 함께 늘어난다`() = runTest {
        val (store, _) = store()

        store.add("n1", "확인.")

        assertEquals(listOf("확인."), store.state.value.comments("n1").map { it.body })
        assertEquals(1, store.state.value.count("n1"))
    }

    /**
     * DB가 `length(btrim(body)) > 0`을 요구한다. 서버까지 가서 거절당하는 대신
     * 여기서 조용히 막는다 — 빈 입력은 오류가 아니라 아무 일도 아니다.
     */
    @Test
    fun `공백뿐인 댓글은 보내지 않는다`() = runTest {
        val (store, repository) = store()

        store.add("n1", "   \n ")

        assertTrue(store.state.value.comments("n1").isEmpty())
        assertNull(store.state.value.errorMessage)
        assertEquals(0, repository.createCalls)
    }

    @Test
    fun `앞뒤 공백은 떼고 저장한다`() = runTest {
        val (store, _) = store()

        store.add("n1", "  확인.  ")

        assertEquals(listOf("확인."), store.state.value.comments("n1").map { it.body })
    }

    /** 저장되지 않은 댓글이 화면에 남으면 쓴 줄 알고 넘어가게 된다. */
    @Test
    fun `작성에 실패하면 끼워 넣었던 댓글을 걷어낸다`() = runTest {
        val (store, repository) = store()
        repository.createError = NotesRepositoryException.Rejected("거절")

        store.add("n1", "확인.")

        assertTrue(store.state.value.comments("n1").isEmpty())
        assertEquals(0, store.state.value.count("n1"))
        assertNotNull(store.state.value.errorMessage)
    }

    @Test
    fun `댓글을 지우면 목록과 개수에서 사라진다`() = runTest {
        val (store, _) = store(
            listOf(
                comment("c1", "n1", "하나", secondsAgo = 20),
                comment("c2", "n1", "둘", secondsAgo = 10),
            ),
        )
        store.load("n1")

        store.delete("c1", "n1")

        assertEquals(listOf("둘"), store.state.value.comments("n1").map { it.body })
        assertEquals(1, store.state.value.count("n1"))
    }

    @Test
    fun `삭제에 실패하면 되돌린다`() = runTest {
        val (store, repository) = store(listOf(comment("c1", "n1", "하나", secondsAgo = 20)))
        store.load("n1")
        repository.deleteError = NotesRepositoryException.Network("끊김")

        store.delete("c1", "n1")

        assertEquals(listOf("하나"), store.state.value.comments("n1").map { it.body })
        assertEquals(1, store.state.value.count("n1"))
        assertNotNull(store.state.value.errorMessage)
    }

    @Test
    fun `오류는 확인하면 사라진다`() = runTest {
        val (store, repository) = store()
        repository.loadError = NotesRepositoryException.Network("끊김")
        store.load("n1")

        store.dismissError()

        assertNull(store.state.value.errorMessage)
    }

    /** 뱃지와 실제 목록이 어긋나면 어느 쪽을 믿어야 할지 알 수 없다. */
    @Test
    fun `목록을 불러오면 개수도 그 목록에 맞춘다`() = runTest {
        val (store, repository) = store(
            listOf(
                comment("c1", "n1", "하나", secondsAgo = 20),
                comment("c2", "n1", "둘", secondsAgo = 10),
            ),
        )
        store.loadCounts()
        repository.remove("c2")

        store.load("n1")

        assertEquals(1, store.state.value.count("n1"))
    }
}
