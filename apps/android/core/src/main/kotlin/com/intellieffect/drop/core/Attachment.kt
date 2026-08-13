package com.intellieffect.drop.core

import java.time.Instant

/**
 * DB의 `attachments.type`. 서버가 새 종류를 먼저 내보내도 목록이 통째로
 * 깨지지 않도록 [UNKNOWN]을 둔다.
 */
enum class AttachmentType(val raw: String) {
    IMAGE("image"),
    AUDIO("audio"),
    VIDEO("video"),
    FILE("file"),
    TEXT("text"),
    INSTAGRAM("instagram"),
    YOUTUBE("youtube"),
    UNKNOWN("unknown"),
    ;

    companion object {
        fun from(raw: String?): AttachmentType = entries.firstOrNull { it.raw == raw } ?: UNKNOWN
    }
}

data class Attachment(
    val id: String,
    val noteId: String,
    val type: AttachmentType,
    val storagePath: String,
    val filename: String? = null,
    val mimeType: String? = null,
    val size: Long? = null,
    val originalUrl: String? = null,
    val authorName: String? = null,
    val authorUrl: String? = null,
    val caption: String? = null,
    val createdAt: Instant,
) {
    val isImage: Boolean get() = type == AttachmentType.IMAGE
    val isVideo: Boolean get() = type == AttachmentType.VIDEO
    val isLink: Boolean get() = type == AttachmentType.INSTAGRAM || type == AttachmentType.YOUTUBE
    val isMedia: Boolean get() = isImage || isVideo || type == AttachmentType.AUDIO
    val isFile: Boolean get() = type == AttachmentType.FILE || type == AttachmentType.TEXT
}
