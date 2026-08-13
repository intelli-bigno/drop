package com.intellieffect.drop.core

import java.time.Instant
import java.util.UUID
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock

/**
 * 테스트와 Compose 프리뷰용 리포지토리. 네트워크 없이 같은 계약을 지킨다.
 * (iOS `InMemoryNotesRepository`와 같은 자리)
 */
class InMemoryNotesRepository(notes: List<Note> = emptyList()) : NotesRepository {
    private val mutex = Mutex()
    private var notes: List<Note> = notes

    /** 실패 경로를 시험하기 위한 손잡이. */
    var loadError: Throwable? = null
    var createError: Throwable? = null
    var mutationError: Throwable? = null

    override suspend fun loadNotes(): List<Note> {
        loadError?.let { throw it }
        return mutex.withLock { NoteAssembler.sorted(notes) }
    }

    override suspend fun createNote(content: String, parentId: String?): Note {
        createError?.let { throw it }
        val now = Instant.now()
        val note = Note(
            id = UUID.randomUUID().toString(),
            displayId = mutex.withLock { notes.size } + 1,
            content = content,
            parentId = parentId,
            createdAt = now,
            updatedAt = now,
            source = NoteSource.MOBILE,
        )
        mutex.withLock { notes = listOf(note) + notes }
        return note
    }

    override suspend fun updateNote(id: String, content: String) =
        mutate(id) { it.copy(content = content) }

    override suspend fun moveToTrash(id: String) =
        mutate(id) { it.copy(archivedAt = null, deletedAt = Instant.now()) }

    override suspend fun restoreFromTrash(id: String) = mutate(id) { it.copy(deletedAt = null) }

    override suspend fun archive(id: String) = mutate(id) { it.copy(archivedAt = Instant.now()) }

    override suspend fun unarchive(id: String) = mutate(id) { it.copy(archivedAt = null) }

    override suspend fun deletePermanently(id: String) {
        mutationError?.let { throw it }
        mutex.withLock { notes = notes.filterNot { it.id == id } }
    }

    override suspend fun emptyTrash() {
        mutationError?.let { throw it }
        mutex.withLock { notes = notes.filterNot { it.isInTrash } }
    }

    override suspend fun setPinned(id: String, isPinned: Boolean) = mutate(id) {
        it.copy(isPinned = isPinned, pinnedAt = if (isPinned) Instant.now() else null)
    }

    override suspend fun setLocked(id: String, isLocked: Boolean) =
        mutate(id) { it.copy(isLocked = isLocked) }

    override suspend fun setPriority(id: String, priority: Int) =
        mutate(id) { it.copy(priority = priority.coerceIn(0, 3)) }

    override suspend fun updateCategories(
        id: String,
        hasLink: Boolean,
        hasMedia: Boolean,
        hasFiles: Boolean,
    ) = mutate(id) { it.copy(hasLink = hasLink, hasMedia = hasMedia, hasFiles = hasFiles) }

    private suspend fun mutate(id: String, transform: (Note) -> Note) {
        mutationError?.let { throw it }
        mutex.withLock {
            notes = notes.map { if (it.id == id) transform(it) else it }
        }
    }
}
