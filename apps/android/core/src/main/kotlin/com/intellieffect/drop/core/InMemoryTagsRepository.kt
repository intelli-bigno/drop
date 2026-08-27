package com.intellieffect.drop.core

import java.time.Clock
import java.time.Instant
import java.util.UUID
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock

/**
 * 테스트와 프리뷰용 태그 리포지토리. 네트워크 없이 [TagsRepository] 계약을 지킨다.
 *
 * 태그는 따로 저장되지 않고 **노트에 실려 다닌다**(`Note.tags`) — Supabase 쪽에서
 * 목록 조회가 `note_tags`를 임베딩해 오는 것과 같은 그림이다. 그래서 이 구현은
 * 자기 저장소가 없고 [InMemoryNotesRepository]의 노트를 고친다. 붙인 태그가
 * 목록을 다시 읽었을 때 보이지 않으면 화면이 거짓말을 하게 된다.
 */
class InMemoryTagsRepository(
    private val notes: InMemoryNotesRepository,
    private val clock: Clock = Clock.systemUTC(),
) : TagsRepository {
    private val mutex = Mutex()

    /** 태그별 마지막 사용 시각. 노트에는 실리지 않는 값이라 여기서만 든다. */
    private val lastUsedAt = mutableMapOf<String, Instant>()

    override suspend fun loadTags(): List<TagWithCount> {
        val occurrences = notes.loadNotes().flatMap { it.tags }.groupBy { it.id }
        return occurrences.values
            .map { tags ->
                TagWithCount(
                    tag = tags.first(),
                    noteCount = tags.size,
                    lastUsedAt = lastUsedAt[tags.first().id],
                )
            }
            // Supabase 쪽 `order=last_used_at.desc.nullslast`와 같은 순서.
            .sortedWith(compareByDescending<TagWithCount> { it.lastUsedAt }.thenBy { it.tag.name })
    }

    override suspend fun addTag(name: String, noteId: String) {
        // 공백뿐인 이름은 태그가 아니다. Supabase 구현과 같이 조용히 넘어간다.
        val normalized = TagName.normalized(name) ?: return
        mutex.withLock {
            val existing = notes.loadNotes().flatMap { it.tags }.firstOrNull { it.name == normalized }
            val tag = existing ?: Tag(
                id = UUID.randomUUID().toString(),
                name = normalized,
                createdAt = clock.instant(),
            )
            lastUsedAt[tag.id] = clock.instant()
            notes.replace(noteId) { note ->
                // 이미 붙어 있으면 조용히 넘어간다 — 중복 연결은 오류가 아니다.
                if (note.tags.any { it.id == tag.id }) note else note.copy(tags = note.tags + tag)
            }
        }
    }

    override suspend fun removeTag(tagId: String, noteId: String) =
        notes.replace(noteId) { note -> note.copy(tags = note.tags.filterNot { it.id == tagId }) }

    override suspend fun renameTag(tagId: String, newName: String) {
        val normalized = TagName.normalized(newName) ?: return
        notes.replaceAll { note ->
            note.copy(tags = note.tags.map { if (it.id == tagId) it.copy(name = normalized) else it })
        }
    }

    override suspend fun deleteTag(tagId: String) {
        lastUsedAt.remove(tagId)
        notes.replaceAll { note -> note.copy(tags = note.tags.filterNot { it.id == tagId }) }
    }
}
