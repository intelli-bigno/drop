package com.intellieffect.drop.core

import java.time.Instant

/**
 * 목록 조회 결과(노트 / 첨부 / 태그)를 화면이 쓰는 형태로 합친다.
 * 순수 함수로 떼어 두어 네트워크 없이 검증한다.
 */
object NoteAssembler {
    fun assemble(
        notes: List<Note>,
        attachments: List<Attachment>,
        tagsByNoteId: Map<String, List<Tag>>,
    ): List<Note> {
        // 주인 없는 첨부(삭제된 노트의 잔여물 등)는 여기서 자연스럽게 버려진다.
        val attachmentsByNoteId = attachments.groupBy { it.noteId }

        return notes.map { note ->
            note.copy(
                attachments = attachmentsByNoteId[note.id].orEmpty(),
                tags = tagsByNoteId[note.id].orEmpty(),
            )
        }
    }

    /**
     * 고정 먼저 → 고정 시각 최신순 → 생성 시각 최신순.
     * 서버 정렬과 같은 규칙을 클라이언트에도 두어, 낙관적 갱신으로 끼워 넣은
     * 노트가 새로고침 전후로 자리를 바꾸지 않게 한다.
     */
    fun sorted(notes: List<Note>): List<Note> = notes.sortedWith(
        compareByDescending<Note> { it.isPinned }
            // 고정 시각이 없는 오래된 데이터도 고정 묶음 안에 남아야 한다.
            .thenByDescending { if (it.isPinned) it.pinnedAt ?: Instant.MIN else Instant.MIN }
            .thenByDescending { it.createdAt },
    )
}
