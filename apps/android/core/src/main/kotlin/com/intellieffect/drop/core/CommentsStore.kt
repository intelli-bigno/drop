package com.intellieffect.drop.core

import java.time.Instant
import java.util.UUID
import kotlin.coroutines.cancellation.CancellationException
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update

/**
 * 댓글 시트와 목록 뱃지가 함께 보는 상태.
 *
 * `NotesState`와 **따로** 둔다 — 댓글은 노트가 아니고, 목록·검색·위젯이 보는
 * `NotesState.visibleNotes`에 섞일 경로 자체가 없어야 한다 (BRU-62의 별도 테이블
 * 설계를 상태에서도 지킨다).
 */
data class CommentsState(
    /** 노트별 댓글 목록. 열어 본 노트만 들어 있다. */
    val commentsByNoteId: Map<String, List<NoteComment>> = emptyMap(),
    /** 노트별 댓글 수 — 목록을 열지 않아도 채워진다(뱃지). */
    val countsByNoteId: Map<String, Int> = emptyMap(),
    val isLoading: Boolean = false,
    val errorMessage: String? = null,
) {
    fun comments(noteId: String): List<NoteComment> = commentsByNoteId[noteId].orEmpty()

    /** 뱃지 숫자. 모르는 노트는 0이고, 화면은 0이면 아무것도 그리지 않는다. */
    fun count(noteId: String): Int = countsByNoteId[noteId] ?: 0
}

/**
 * iOS `CommentsStore`와 같은 상태 홀더. Android SDK에 의존하지 않으므로
 * 에뮬레이터 없이 검증된다.
 *
 * 실패 규칙은 [NotesStore]와 같다(BRU-51): 로드 실패는 보고 있던 목록을 지우지 않고,
 * 취소는 오류가 아니며, 작성·삭제는 낙관적으로 먼저 반영하고 실패하면 되돌린다.
 */
class CommentsStore(private val repository: CommentsRepository) {
    private val _state = MutableStateFlow(CommentsState())
    val state: StateFlow<CommentsState> = _state.asStateFlow()

    // MARK: - 로드

    suspend fun load(noteId: String) {
        _state.update { it.copy(isLoading = true, errorMessage = null) }
        try {
            val loaded = repository.loadComments(noteId).sortedBy { it.createdAt }
            _state.update { it.withComments(noteId, loaded) }
        } catch (cancellation: CancellationException) {
            // 취소는 실패가 아니다 — 시트를 닫거나 당겨서 새로고침에서 손을 떼면
            // 요청이 취소된다. 목록도 오류 문구도 건드리지 않고 취소만 다시 던진다.
            _state.update { it.copy(isLoading = false) }
            throw cancellation
        } catch (error: Throwable) {
            // 실패한 것은 "새 목록을 받아오는 일"이지 이미 받아 둔 목록이 아니다.
            _state.update { it.copy(errorMessage = RepositoryErrorMessage.text(error)) }
        }
        _state.update { it.copy(isLoading = false) }
    }

    /** 목록 화면이 뱃지를 채우기 위해 한 번 부른다. */
    suspend fun loadCounts() {
        try {
            val counts = repository.loadCommentCounts()
            _state.update { it.copy(countsByNoteId = counts) }
        } catch (cancellation: CancellationException) {
            throw cancellation
        } catch (error: Throwable) {
            _state.update { it.copy(errorMessage = RepositoryErrorMessage.text(error)) }
        }
    }

    // MARK: - 작성 · 삭제

    /**
     * 저장을 기다리지 않고 먼저 끼워 넣는다. 실패하면 걷어낸다 —
     * 남겨 두면 저장되지도 않은 댓글이 화면에 남아 쓴 줄 알고 넘어가게 된다.
     */
    suspend fun add(noteId: String, body: String) {
        val trimmed = body.trim()
        // DB가 `length(btrim(body)) > 0`을 요구한다. 서버까지 가서 거절당하는 대신
        // 여기서 조용히 막는다 — 빈 입력은 오류가 아니라 아무 일도 아니다.
        if (trimmed.isEmpty()) return

        val now = Instant.now()
        val placeholder = NoteComment(
            id = "임시-${UUID.randomUUID()}",
            noteId = noteId,
            body = trimmed,
            createdAt = now,
            updatedAt = now,
        )
        _state.update { it.withComments(noteId, it.comments(noteId) + placeholder) }

        try {
            val created = repository.createComment(noteId, trimmed)
            _state.update { state ->
                state.withComments(
                    noteId,
                    state.comments(noteId).map { if (it.id == placeholder.id) created else it },
                )
            }
        } catch (error: Throwable) {
            _state.update { state ->
                state.withComments(
                    noteId,
                    state.comments(noteId).filterNot { it.id == placeholder.id },
                )
            }
            if (error is CancellationException) throw error
            _state.update { it.copy(errorMessage = RepositoryErrorMessage.text(error)) }
        }
    }

    /** 하드 삭제 — 댓글에는 휴지통이 없다. */
    suspend fun delete(id: String, noteId: String) {
        val backup = _state.value.comments(noteId)
        _state.update { it.withComments(noteId, backup.filterNot { comment -> comment.id == id }) }

        try {
            repository.deleteComment(id)
        } catch (error: Throwable) {
            _state.update { it.withComments(noteId, backup) }
            if (error is CancellationException) throw error
            _state.update { it.copy(errorMessage = RepositoryErrorMessage.text(error)) }
        }
    }

    fun dismissError() = _state.update { it.copy(errorMessage = null) }

    /** 로그아웃하면 앞 사용자의 댓글이 남아 있으면 안 된다. */
    fun clear() = _state.update { CommentsState() }
}

/**
 * 목록과 개수를 **함께** 갱신한다. 따로 두면 뱃지와 실제 목록이 어긋나
 * 어느 쪽을 믿어야 할지 알 수 없게 된다.
 */
private fun CommentsState.withComments(
    noteId: String,
    comments: List<NoteComment>,
): CommentsState {
    val sorted = comments.sortedBy { it.createdAt }
    return copy(
        commentsByNoteId = commentsByNoteId + (noteId to sorted),
        countsByNoteId = countsByNoteId + (noteId to sorted.size),
    )
}
