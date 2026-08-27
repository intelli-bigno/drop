package com.intellieffect.drop.core

import java.time.Instant
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlinx.coroutines.test.runTest

class InMemoryNotesRepositoryTest {
    private fun note(id: String, content: String = id) = Note(
        id = id,
        displayId = 1,
        content = content,
        createdAt = Instant.EPOCH,
        updatedAt = Instant.EPOCH,
        source = NoteSource.MOBILE,
    )

    @Test
    fun replaceTransformsOnlyTheMatchingNote() = runTest {
        val repository = InMemoryNotesRepository(listOf(note("a"), note("b")))
        val tag = Tag(id = "t", name = "t", createdAt = Instant.EPOCH)

        repository.replace("a") { it.copy(tags = listOf(tag)) }

        val byId = repository.loadNotes().associateBy { it.id }
        assertEquals(listOf(tag), byId.getValue("a").tags)
        assertEquals(emptyList(), byId.getValue("b").tags)
    }

    @Test
    fun replaceWithUnknownIdChangesNothing() = runTest {
        val repository = InMemoryNotesRepository(listOf(note("a")))

        repository.replace("missing") { it.copy(content = "changed") }

        assertEquals("a", repository.loadNotes().single().content)
    }
}
