package com.intellieffect.drop.core

import kotlin.coroutines.cancellation.CancellationException

/**
 * 다른 앱에서 공유해 온 것을 노트로 담는다 (iOS `SharedInbox`와 같은 자리).
 *
 * 인텐트를 읽는 일은 `app`이 하고, **무엇을 어떤 순서로 저장하는지는 여기서** 정한다 —
 * 순서가 곧 실패 시 남는 것을 결정하기 때문에 테스트로 덮어야 하는 규칙이다.
 */
class SharedCapture(
    private val notes: NotesRepository,
    private val attachments: AttachmentsRepository,
) {
    /** 공유해 온 파일. 바이트는 **노트를 만들기 전에** 미리 읽어 둔다. */
    data class SharedFile(val name: String, val type: AttachmentType, val bytes: ByteArray) {
        override fun equals(other: Any?): Boolean =
            other is SharedFile && name == other.name && type == other.type &&
                bytes.contentEquals(other.bytes)

        override fun hashCode(): Int = (name.hashCode() * 31 + type.hashCode()) * 31 +
            bytes.contentHashCode()
    }

    data class Payload(
        val text: String? = null,
        val subject: String? = null,
        val files: List<SharedFile> = emptyList(),
    )

    /**
     * 담았으면 만들어진 노트, 담을 것이 없으면 `null`.
     *
     * 실패하면 **만든 노트를 되돌린다.** 첨부를 담으려고 공유했는데 파일 없는 빈 노트만
     * 남으면, 사용자는 실패한 줄도 모르고 쓸모없는 노트를 손으로 지워야 한다.
     */
    suspend fun capture(payload: Payload): Note? {
        val content = content(payload) ?: return null

        val note = notes.createNote(content, parentId = null)

        return try {
            payload.files.forEach { file ->
                attachments.upload(
                    bytes = file.bytes,
                    fileName = file.name,
                    type = file.type,
                    noteId = note.id,
                )
            }
            if (payload.files.isNotEmpty()) {
                // 카테고리 필터(미디어·파일)에 걸리도록 플래그를 세운다 —
                // 안 하면 첨부는 붙었는데 해당 탭에서 보이지 않는다.
                val hasMedia = payload.files.any {
                    it.type == AttachmentType.IMAGE ||
                        it.type == AttachmentType.VIDEO ||
                        it.type == AttachmentType.AUDIO
                }
                notes.updateCategories(
                    id = note.id,
                    hasLink = false,
                    hasMedia = hasMedia,
                    hasFiles = payload.files.any { !hasMedia },
                )
            }
            note
        } catch (cancellation: CancellationException) {
            throw cancellation
        } catch (error: Throwable) {
            runCatching { notes.deletePermanently(note.id) }
            throw error
        }
    }

    /**
     * 본문은 **원문 그대로** 담는다. 제목이 따로 왔으면 위에 한 줄 붙인다 —
     * 공유해 온 것이 무엇이었는지 나중에 알 수 있어야 한다.
     */
    private fun content(payload: Payload): String? {
        val parts = listOfNotNull(
            payload.subject?.takeIf { it.isNotBlank() },
            payload.text?.takeIf { it.isNotBlank() },
        ).distinct()

        return when {
            parts.isNotEmpty() -> parts.joinToString("\n")
            // 파일만 온 경우. 본문이 비어 있으면 목록에서 무엇인지 알 수 없으므로 이름을 적는다.
            payload.files.isNotEmpty() -> payload.files.joinToString("\n") { it.name }
            else -> null
        }
    }
}
