package com.intellieffect.drop.core

import io.ktor.client.HttpClient
import io.ktor.client.request.header
import io.ktor.client.request.setBody
import io.ktor.http.ContentType
import io.ktor.http.contentType
import java.time.Clock
import java.time.Instant
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put

data class TagWithCount(val tag: Tag, val noteCount: Int, val lastUsedAt: Instant?)

/** 태그 편집 경계 (iOS `TagsRepository`와 같은 계약). */
interface TagsRepository {
    suspend fun loadTags(): List<TagWithCount>

    /** 이름이 같은 태그가 있으면 재사용하고, 없으면 만든다. */
    suspend fun addTag(name: String, noteId: String)
    suspend fun removeTag(tagId: String, noteId: String)
    suspend fun renameTag(tagId: String, newName: String)
    suspend fun deleteTag(tagId: String)
}

object TagName {
    /**
     * 같은 태그가 대소문자·공백 때문에 둘로 갈라지지 않도록 좁힌다.
     * **iOS·Flutter와 같은 규칙이어야 한다** — 앱마다 다르면 `work`와 `Work`가 따로 생긴다.
     */
    fun normalized(raw: String): String? = raw.trim().lowercase().takeIf { it.isNotEmpty() }
}

class SupabaseTagsRepository(
    private val config: DropConfiguration,
    private val client: HttpClient,
    private val tokens: AuthTokenProvider,
    private val clock: Clock = Clock.systemUTC(),
) : TagsRepository {
    private val rest = SupabaseRest(config, client, tokens)

    override suspend fun loadTags(): List<TagWithCount> {
        // note_tags(count)는 PostgREST의 집계 임베딩이다 — 태그별 노트 수를
        // 한 번에 받아 온다. 태그마다 세면 태그 수만큼 요청이 나간다.
        val rows: List<TagCountRow> =
            rest.get("tags?select=*,note_tags(count)&order=last_used_at.desc.nullslast")
        return rows.map { it.toTagWithCount() }
    }

    override suspend fun addTag(name: String, noteId: String) {
        // 공백뿐인 이름은 태그가 아니다. 조용히 넘어간다 — 오류창을 띄울 일이 아니다.
        val normalized = TagName.normalized(name) ?: return
        val userId = tokens.userId ?: throw NotesRepositoryException.NotAuthenticated
        val timestamp = PostgresTimestamp.format(clock.instant())

        val existing: List<TagRow> = rest.get("tags?select=*&name=eq.$normalized&limit=1")

        val tagId = existing.firstOrNull()?.id ?: rest.postReturning<List<TagRow>>(
            path = "tags?select=*",
            body = buildJsonObject {
                put("name", normalized)
                // notes와 같은 이유로 user_id를 직접 넣는다 (기본값 없음 + RLS WITH CHECK).
                put("user_id", userId)
                put("last_used_at", timestamp)
            },
        ).firstOrNull()?.id ?: throw NotesRepositoryException.Decoding("태그 삽입 결과가 없습니다")

        if (existing.isNotEmpty()) {
            // 최근 쓴 태그가 위로 오도록 시각을 갱신한다.
            rest.patch("tags?id=eq.$tagId", buildJsonObject { put("last_used_at", timestamp) })
        }

        // 이미 연결돼 있으면 조용히 넘어가야 한다 — 중복 연결은 오류가 아니다.
        rest.post(
            path = "note_tags",
            body = buildJsonObject {
                put("note_id", noteId)
                put("tag_id", tagId)
            },
        ) {
            header("Prefer", "resolution=merge-duplicates")
        }
    }

    override suspend fun removeTag(tagId: String, noteId: String) {
        rest.delete("note_tags?note_id=eq.$noteId&tag_id=eq.$tagId")
    }

    override suspend fun renameTag(tagId: String, newName: String) {
        val normalized = TagName.normalized(newName) ?: return
        rest.patch("tags?id=eq.$tagId", buildJsonObject { put("name", normalized) })
    }

    override suspend fun deleteTag(tagId: String) {
        // note_tags는 CASCADE로 함께 지워진다.
        rest.delete("tags?id=eq.$tagId")
    }
}
