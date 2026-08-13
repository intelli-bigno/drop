package com.intellieffect.drop.core

import java.time.Instant

/**
 * 노트를 만든 곳. 서버가 아직 우리가 모르는 값을 보내도 목록 전체가 깨지지 않도록
 * [UNKNOWN]을 둔다 (iOS `NoteSource`와 같은 이유).
 */
enum class NoteSource(val raw: String) {
    MOBILE("mobile"),
    DESKTOP("desktop"),
    WEB("web"),
    MCP("mcp"),
    UNKNOWN("unknown"),
    ;

    companion object {
        fun from(raw: String?): NoteSource = entries.firstOrNull { it.raw == raw } ?: UNKNOWN
    }
}

/** 목록 화면의 상단 탭. */
enum class NoteViewMode { ACTIVE, ARCHIVED, TRASH }

/** 목록 화면의 카테고리 필터. */
enum class NoteCategory { ALL, LINKS, MEDIA, FILES }

data class Note(
    val id: String,
    val displayId: Int,
    val content: String,
    val parentId: String? = null,
    val attachments: List<Attachment> = emptyList(),
    val tags: List<Tag> = emptyList(),
    val createdAt: Instant,
    val updatedAt: Instant,
    val source: NoteSource,
    val archivedAt: Instant? = null,
    val deletedAt: Instant? = null,
    val isDeleted: Boolean = false,
    val hasLink: Boolean = false,
    val hasMedia: Boolean = false,
    val hasFiles: Boolean = false,
    val isLocked: Boolean = false,
    val isPinned: Boolean = false,
    val pinnedAt: Instant? = null,
    val priority: Int = 0,
) {
    val isReply: Boolean get() = parentId != null
    val isArchived: Boolean get() = archivedAt != null
    val isInTrash: Boolean get() = deletedAt != null
    val isActive: Boolean get() = !isArchived && !isInTrash

    fun matches(viewMode: NoteViewMode): Boolean = when (viewMode) {
        NoteViewMode.ACTIVE -> isActive
        NoteViewMode.ARCHIVED -> isArchived
        NoteViewMode.TRASH -> isInTrash
    }

    fun matches(category: NoteCategory): Boolean = when (category) {
        NoteCategory.ALL -> true
        NoteCategory.LINKS -> hasLink
        NoteCategory.MEDIA -> hasMedia
        NoteCategory.FILES -> hasFiles
    }
}
