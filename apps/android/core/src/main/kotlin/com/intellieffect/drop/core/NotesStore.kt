package com.intellieffect.drop.core

import java.time.Instant
import java.util.UUID
import kotlin.coroutines.cancellation.CancellationException
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update

/**
 * iOS `NotesStore`와 같은 상태 홀더. Android SDK에 의존하지 않으므로
 * ViewModel 없이도, 에뮬레이터 없이도 검증된다.
 */
class NotesStore(private val repository: NotesRepository) {
    private val _state = MutableStateFlow(NotesState())
    val state: StateFlow<NotesState> = _state.asStateFlow()

    suspend fun load() {
        _state.update { it.copy(isLoading = true, errorMessage = null) }
        try {
            val notes = repository.loadNotes()
            _state.update { it.copy(allNotes = NoteAssembler.sorted(notes)) }
        } catch (cancellation: CancellationException) {
            // 취소는 실패가 아니다. 당겨서 새로고침에서 손을 떼거나 화면을 벗어나면
            // 요청이 취소되는데, 이걸 오류로 다루면 아무 잘못 없이 오류창이 뜨고
            // 보고 있던 목록까지 지워진다. 목록도 오류 문구도 건드리지 않는다.
            // 구조적 동시성을 지키기 위해 취소 자체는 다시 던진다.
            _state.update { it.copy(isLoading = false) }
            throw cancellation
        } catch (error: Throwable) {
            _state.update { it.copy(allNotes = emptyList(), errorMessage = messageFor(error)) }
        }
        _state.update { it.copy(isLoading = false) }
    }

    suspend fun create(content: String) {
        // 저장을 기다리지 않고 먼저 끼워 넣는다. 실패하면 걷어낸다 —
        // 남겨 두면 저장되지도 않은 노트가 목록에 남는다.
        val now = Instant.now()
        val placeholder = Note(
            id = "임시-${UUID.randomUUID()}",
            displayId = 0,
            content = content,
            createdAt = now,
            updatedAt = now,
            source = NoteSource.MOBILE,
        )
        _state.update { it.copy(allNotes = listOf(placeholder) + it.allNotes) }

        try {
            val created = repository.createNote(content, parentId = null)
            replace(placeholder.id, created)
        } catch (error: Throwable) {
            _state.update { it.copy(allNotes = it.allNotes.filterNot { note -> note.id == placeholder.id }) }
            if (error is CancellationException) throw error
            _state.update { it.copy(errorMessage = messageFor(error)) }
        }
    }

    suspend fun update(id: String, content: String) =
        mutate(id, { it.copy(content = content, updatedAt = Instant.now()) }) {
            repository.updateNote(id, content)
        }

    suspend fun moveToTrash(id: String) =
        mutate(id, { it.copy(archivedAt = null, deletedAt = Instant.now()) }) {
            repository.moveToTrash(id)
        }

    suspend fun restore(id: String) =
        mutate(id, { it.copy(deletedAt = null) }) { repository.restoreFromTrash(id) }

    suspend fun archive(id: String) =
        mutate(id, { it.copy(archivedAt = Instant.now()) }) { repository.archive(id) }

    suspend fun unarchive(id: String) =
        mutate(id, { it.copy(archivedAt = null) }) { repository.unarchive(id) }

    suspend fun setPinned(id: String, isPinned: Boolean) = mutate(
        id,
        { it.copy(isPinned = isPinned, pinnedAt = if (isPinned) Instant.now() else null) },
    ) {
        repository.setPinned(id, isPinned)
    }

    suspend fun deletePermanently(id: String) {
        val backup = _state.value.allNotes
        _state.update { it.copy(allNotes = it.allNotes.filterNot { note -> note.id == id }) }
        try {
            repository.deletePermanently(id)
        } catch (error: Throwable) {
            _state.update { it.copy(allNotes = backup) }
            if (error is CancellationException) throw error
            _state.update { it.copy(errorMessage = messageFor(error)) }
        }
    }

    // MARK: - 필터

    fun setViewMode(viewMode: NoteViewMode) = _state.update { it.copy(viewMode = viewMode) }

    fun setCategory(category: NoteCategory) = _state.update { it.copy(category = category) }

    fun setSelectedTagId(tagId: String?) = _state.update { it.copy(selectedTagId = tagId) }

    fun setSearchText(text: String) = _state.update { it.copy(searchText = text) }

    // MARK: - 선택 모드

    fun toggleSelection(id: String) = _state.update {
        val next = if (id in it.selectedIds) it.selectedIds - id else it.selectedIds + id
        it.copy(selectedIds = next)
    }

    fun clearSelection() = _state.update { it.copy(selectedIds = emptySet()) }

    fun dismissError() = _state.update { it.copy(errorMessage = null) }

    /** 화면 쪽(첨부 업로드 등)에서 생긴 오류도 같은 자리에 보여 준다. */
    fun report(error: Throwable) = _state.update { it.copy(errorMessage = messageFor(error)) }

    suspend fun trashSelected() {
        val targets = _state.value.selectedIds
        // 일괄 처리 전에 선택을 비운다. 남겨 두면 다음 탭이 엉뚱한 노트에 걸린다.
        clearSelection()
        targets.forEach { moveToTrash(it) }
    }

    suspend fun deleteSelectedPermanently() {
        val targets = _state.value.selectedIds
        clearSelection()
        targets.forEach { deletePermanently(it) }
    }

    // MARK: - 내부

    private suspend fun mutate(
        id: String,
        optimistic: (Note) -> Note,
        perform: suspend () -> Unit,
    ) {
        val backup = _state.value.allNotes.firstOrNull { it.id == id } ?: return
        replace(id, optimistic(backup))

        try {
            perform()
        } catch (error: Throwable) {
            replace(id, backup)
            if (error is CancellationException) throw error
            _state.update { it.copy(errorMessage = messageFor(error)) }
        }
    }

    private fun replace(id: String, note: Note) = _state.update { state ->
        if (state.allNotes.none { it.id == id }) return@update state
        state.copy(
            allNotes = NoteAssembler.sorted(state.allNotes.map { if (it.id == id) note else it }),
        )
    }

    private fun messageFor(error: Throwable): String = when (error) {
        is NotesRepositoryException.NotAuthenticated -> "로그인이 필요합니다."
        is NotesRepositoryException.Rejected -> "서버가 요청을 거절했습니다: ${error.reason}"
        is NotesRepositoryException.Network -> "네트워크에 연결하지 못했습니다."
        is NotesRepositoryException.Decoding -> "응답을 이해하지 못했습니다."
        else -> error.message ?: error.toString()
    }
}
