package com.intellieffect.drop.core

import java.time.Instant
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlinx.coroutines.test.runTest

/**
 * 태그는 노트에 실려 다닌다(`Note.tags`). 인메모리 태그 리포지토리도 같은 그림이어야
 * 한다 — 태그를 붙이면 노트 목록을 다시 읽었을 때 그 노트에 붙어 있어야 한다.
 */
class InMemoryTagsRepositoryTest {
    private fun note(id: String, tags: List<Tag> = emptyList()) = Note(
        id = id,
        displayId = 1,
        content = id,
        tags = tags,
        createdAt = Instant.EPOCH,
        updatedAt = Instant.EPOCH,
        source = NoteSource.MOBILE,
    )

    private fun fixture(vararg notes: Note): Pair<InMemoryTagsRepository, InMemoryNotesRepository> {
        val notesRepository = InMemoryNotesRepository(notes.toList())
        return InMemoryTagsRepository(notesRepository) to notesRepository
    }

    private suspend fun InMemoryNotesRepository.tagsOf(id: String): List<String> =
        loadNotes().first { it.id == id }.tags.map { it.name }

    @Test
    fun addTagAttachesNormalizedNameToTheNote() = runTest {
        val (tags, notes) = fixture(note("a"))

        tags.addTag("  Work ", "a")

        assertEquals(listOf("work"), notes.tagsOf("a"))
    }

    @Test
    fun addTagReusesTheSameTagAcrossNotes() = runTest {
        val (tags, notes) = fixture(note("a"), note("b"))

        tags.addTag("work", "a")
        tags.addTag("WORK", "b")

        val ids = notes.loadNotes().flatMap { it.tags }.map { it.id }.toSet()
        assertEquals(1, ids.size)
        assertEquals(2, tags.loadTags().single().noteCount)
    }

    @Test
    fun addTagTwiceToTheSameNoteDoesNotDuplicate() = runTest {
        val (tags, notes) = fixture(note("a"))

        tags.addTag("work", "a")
        tags.addTag("work", "a")

        assertEquals(listOf("work"), notes.tagsOf("a"))
    }

    @Test
    fun blankNameIsIgnored() = runTest {
        val (tags, notes) = fixture(note("a"))

        tags.addTag("   ", "a")

        assertEquals(emptyList(), notes.tagsOf("a"))
    }

    @Test
    fun loadTagsCountsNotesPerTagIncludingSeededOnes() = runTest {
        val seeded = Tag(id = "seed", name = "seed", createdAt = Instant.EPOCH)
        val (tags, _) = fixture(note("a", listOf(seeded)), note("b", listOf(seeded)), note("c"))

        tags.addTag("fresh", "c")

        val counts = tags.loadTags().associate { it.tag.name to it.noteCount }
        assertEquals(mapOf("seed" to 2, "fresh" to 1), counts)
        assertNotNull(tags.loadTags().first { it.tag.name == "fresh" }.lastUsedAt)
    }

    @Test
    fun removeTagDetachesFromThatNoteOnly() = runTest {
        val (tags, notes) = fixture(note("a"), note("b"))
        tags.addTag("work", "a")
        tags.addTag("work", "b")
        val tagId = notes.loadNotes().first { it.id == "a" }.tags.single().id

        tags.removeTag(tagId, "a")

        assertEquals(emptyList(), notes.tagsOf("a"))
        assertEquals(listOf("work"), notes.tagsOf("b"))
    }

    @Test
    fun renameTagRenamesOnEveryNote() = runTest {
        val (tags, notes) = fixture(note("a"), note("b"))
        tags.addTag("work", "a")
        tags.addTag("work", "b")
        val tagId = notes.loadNotes().first { it.id == "a" }.tags.single().id

        tags.renameTag(tagId, " Office ")

        assertEquals(listOf("office"), notes.tagsOf("a"))
        assertEquals(listOf("office"), notes.tagsOf("b"))
    }

    @Test
    fun deleteTagRemovesFromEveryNote() = runTest {
        val (tags, notes) = fixture(note("a"), note("b"))
        tags.addTag("work", "a")
        tags.addTag("work", "b")
        tags.addTag("keep", "b")
        val tagId = notes.loadNotes().first { it.id == "a" }.tags.single().id

        tags.deleteTag(tagId)

        assertEquals(emptyList(), notes.tagsOf("a"))
        assertEquals(listOf("keep"), notes.tagsOf("b"))
        assertEquals(listOf("keep"), tags.loadTags().map { it.tag.name })
    }
}
