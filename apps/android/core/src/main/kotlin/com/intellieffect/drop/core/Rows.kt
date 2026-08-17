package com.intellieffect.drop.core

import java.time.Instant
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * PostgREST가 돌려주는 행들. 도메인 타입과 따로 두는 이유:
 * 서버 컬럼 이름·널 허용 여부가 화면이 쓰는 모델을 오염시키지 않게 하려는 것이다.
 *
 * 모든 필드에 기본값을 둔다 — 컬럼이 하나 빠져 오거나 늘어도 목록 전체가
 * 파싱 실패로 비어 버리는 일을 막는다.
 */
@Serializable
internal data class NoteRow(
    val id: String,
    @SerialName("display_id") val displayId: Int = 0,
    val content: String? = null,
    @SerialName("parent_id") val parentId: String? = null,
    @Serializable(with = InstantSerializer::class) @SerialName("created_at") val createdAt: Instant,
    @Serializable(with = InstantSerializer::class) @SerialName("updated_at") val updatedAt: Instant,
    val source: String? = null,
    @Serializable(with = InstantSerializer::class) @SerialName("archived_at") val archivedAt: Instant? = null,
    @Serializable(with = InstantSerializer::class) @SerialName("deleted_at") val deletedAt: Instant? = null,
    @SerialName("is_deleted") val isDeleted: Boolean = false,
    @SerialName("has_link") val hasLink: Boolean = false,
    @SerialName("has_media") val hasMedia: Boolean = false,
    @SerialName("has_files") val hasFiles: Boolean = false,
    @SerialName("is_locked") val isLocked: Boolean = false,
    @SerialName("is_pinned") val isPinned: Boolean = false,
    @Serializable(with = InstantSerializer::class) @SerialName("pinned_at") val pinnedAt: Instant? = null,
    val priority: Int = 0,
) {
    fun toNote(): Note = Note(
        id = id,
        displayId = displayId,
        // content는 NULL을 허용하는 컬럼이다. 빈 노트도 목록에 남아야 한다.
        content = content.orEmpty(),
        parentId = parentId,
        createdAt = createdAt,
        updatedAt = updatedAt,
        source = NoteSource.from(source),
        archivedAt = archivedAt,
        deletedAt = deletedAt,
        isDeleted = isDeleted,
        hasLink = hasLink,
        hasMedia = hasMedia,
        hasFiles = hasFiles,
        isLocked = isLocked,
        isPinned = isPinned,
        pinnedAt = pinnedAt,
        priority = priority,
    )
}

@Serializable
internal data class AttachmentRow(
    val id: String,
    @SerialName("note_id") val noteId: String,
    val type: String? = null,
    @SerialName("storage_path") val storagePath: String,
    val filename: String? = null,
    @SerialName("mime_type") val mimeType: String? = null,
    val size: Long? = null,
    @SerialName("original_url") val originalUrl: String? = null,
    @SerialName("author_name") val authorName: String? = null,
    @SerialName("author_url") val authorUrl: String? = null,
    val caption: String? = null,
    @Serializable(with = InstantSerializer::class) @SerialName("created_at") val createdAt: Instant,
) {
    fun toAttachment(): Attachment = Attachment(
        id = id,
        noteId = noteId,
        type = AttachmentType.from(type),
        storagePath = storagePath,
        filename = filename,
        mimeType = mimeType,
        size = size,
        originalUrl = originalUrl,
        authorName = authorName,
        authorUrl = authorUrl,
        caption = caption,
        createdAt = createdAt,
    )
}

@Serializable
internal data class TagRow(
    val id: String,
    val name: String,
    @Serializable(with = InstantSerializer::class) @SerialName("created_at") val createdAt: Instant,
    @Serializable(with = InstantSerializer::class) @SerialName("last_used_at") val lastUsedAt: Instant? = null,
) {
    fun toTag(): Tag = Tag(id = id, name = name, createdAt = createdAt)
}

/**
 * `tags?select=*,note_tags(count)` 의 한 행.
 *
 * PostgREST의 집계 임베딩은 `[{"count": 3}]` 모양으로 온다. 태그마다 따로 세면
 * 태그 수만큼 요청이 나가므로 한 번에 받는다.
 */
@Serializable
internal data class TagCountRow(
    val id: String,
    val name: String,
    @Serializable(with = InstantSerializer::class) @SerialName("created_at") val createdAt: Instant,
    @Serializable(with = InstantSerializer::class) @SerialName("last_used_at") val lastUsedAt: Instant? = null,
    @SerialName("note_tags") val noteTags: List<CountRow> = emptyList(),
) {
    @Serializable
    internal data class CountRow(val count: Int = 0)

    fun toTagWithCount(): TagWithCount = TagWithCount(
        tag = Tag(id = id, name = name, createdAt = createdAt),
        noteCount = noteTags.firstOrNull()?.count ?: 0,
        lastUsedAt = lastUsedAt,
    )
}

/** `note_tags?select=note_id,tags(*)` 의 한 행. */
@Serializable
internal data class NoteTagRow(
    @SerialName("note_id") val noteId: String,
    val tags: TagRow? = null,
)
