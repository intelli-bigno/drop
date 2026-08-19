package com.intellieffect.drop.core

import java.time.Instant

/**
 * 노트에 달린 댓글. **노트가 아니다** — 태그·첨부·우선순위·보관·잠금이 없고,
 * 목록·검색·Inbox·위젯 어디에도 노트로 나타나지 않는다 (BRU-62의 별도 테이블 설계).
 *
 * `notes.parent_id`(하위 노트)와도 다른 것이다. 하위 노트는 그 자체로 노트라
 * 피드에 쌓이지만, 댓글은 노트 옆에 붙는 짧은 응답이다.
 *
 * 소프트 삭제도 없다. 지우면 즉시 사라지고, 노트를 휴지통에 넣어도 댓글은 남는다
 * (노트를 영구 삭제할 때만 ON DELETE CASCADE로 함께 사라진다).
 */
data class NoteComment(
    val id: String,
    val noteId: String,
    val body: String,
    val createdAt: Instant,
    val updatedAt: Instant,
)
