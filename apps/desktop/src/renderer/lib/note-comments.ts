// 노트 댓글의 순수 로직 (BRU-63).
//
// 스토어가 하는 일 중 네트워크가 아닌 것 — 개수 집계, 정렬, 낙관적 삽입의 상태 전이 —
// 은 전부 여기 있다. 스토어는 이 함수들을 부르기만 한다.

import type { NoteComment } from '@drop/shared'

/** 카드 뱃지에 쓸 노트별 댓글 개수. 0인 노트는 키를 만들지 않는다. */
export function countCommentsByNote(rows: { note_id: string }[]): Record<string, number> {
  const counts: Record<string, number> = {}
  for (const row of rows) {
    counts[row.note_id] = (counts[row.note_id] ?? 0) + 1
  }
  return counts
}

/** 오래된 댓글이 위 — 대화는 위에서 아래로 읽힌다. */
export function sortCommentsOldestFirst(comments: NoteComment[]): NoteComment[] {
  return [...comments].sort((a, b) => a.createdAt.getTime() - b.createdAt.getTime())
}

/** 낙관적 댓글은 맨 뒤에 붙는다 — 방금 쓴 것이 가장 최신이다. */
export function insertOptimisticComment(
  comments: NoteComment[],
  optimistic: NoteComment
): NoteComment[] {
  return [...comments, optimistic]
}

/** 서버 응답이 오면 같은 자리에서 실제 댓글로 갈아 끼운다. */
export function confirmOptimisticComment(
  comments: NoteComment[],
  optimisticId: string,
  saved: NoteComment
): NoteComment[] {
  return comments.map((c) => (c.id === optimisticId ? { ...saved, isPending: false } : c))
}

/** 실패하면 낙관적 댓글만 걷어낸다. */
export function rollbackOptimisticComment(
  comments: NoteComment[],
  optimisticId: string
): NoteComment[] {
  return comments.filter((c) => c.id !== optimisticId)
}

/** 뱃지 개수 증감. 0이면 키를 지운다 — 0짜리 뱃지가 남지 않게. */
export function adjustCommentCount(
  counts: Record<string, number>,
  noteId: string,
  delta: number
): Record<string, number> {
  const next = { ...counts }
  const value = (next[noteId] ?? 0) + delta
  if (value <= 0) delete next[noteId]
  else next[noteId] = value
  return next
}

export function normalizeCommentBody(body: string): string {
  return body.trim()
}

export function canSubmitComment(body: string): boolean {
  return normalizeCommentBody(body).length > 0
}

const DELETE_PREVIEW_MAX_LENGTH = 60

/** 삭제 확인 다이얼로그에 무엇이 지워지는지 인용한다 — 되돌릴 수 없으므로. */
export function commentDeleteMessage(body: string): string {
  const collapsed = normalizeCommentBody(body).replace(/\s+/g, ' ')
  const preview =
    collapsed.length > DELETE_PREVIEW_MAX_LENGTH
      ? `${collapsed.slice(0, DELETE_PREVIEW_MAX_LENGTH)}…`
      : collapsed
  return `"${preview}" 댓글을 삭제합니다. 되돌릴 수 없습니다.`
}
