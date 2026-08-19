package com.intellieffect.drop.core

import java.time.Instant
import java.util.UUID
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock

/**
 * 테스트와 Compose 프리뷰용 댓글 리포지토리. 네트워크 없이 같은 계약을 지킨다.
 * (iOS `InMemoryCommentsRepository`와 같은 자리)
 */
class InMemoryCommentsRepository(comments: List<NoteComment> = emptyList()) : CommentsRepository {
    private val mutex = Mutex()
    private var comments: List<NoteComment> = comments

    /** 실패 경로를 시험하기 위한 손잡이. */
    var loadError: Throwable? = null
    var createError: Throwable? = null
    var deleteError: Throwable? = null

    /** 개수를 노트마다 세지 않고 한 번에 받는지 확인하기 위한 계수기. */
    var countCalls: Int = 0
        private set
    var createCalls: Int = 0
        private set

    override suspend fun loadComments(noteId: String): List<NoteComment> {
        loadError?.let { throw it }
        return mutex.withLock {
            comments.filter { it.noteId == noteId }.sortedBy { it.createdAt }
        }
    }

    override suspend fun loadCommentCounts(): Map<String, Int> {
        countCalls += 1
        loadError?.let { throw it }
        return mutex.withLock { comments.groupingBy { it.noteId }.eachCount() }
    }

    override suspend fun createComment(noteId: String, body: String): NoteComment {
        createError?.let { throw it }
        createCalls += 1
        val now = Instant.now()
        val comment = NoteComment(
            id = UUID.randomUUID().toString(),
            noteId = noteId,
            body = body,
            createdAt = now,
            updatedAt = now,
        )
        mutex.withLock { comments = comments + comment }
        return comment
    }

    override suspend fun deleteComment(id: String) {
        deleteError?.let { throw it }
        mutex.withLock { comments = comments.filterNot { it.id == id } }
    }

    /** 서버 쪽이 먼저 바뀐 상황을 만들기 위한 시험용 손잡이. */
    fun remove(id: String) {
        comments = comments.filterNot { it.id == id }
    }
}
