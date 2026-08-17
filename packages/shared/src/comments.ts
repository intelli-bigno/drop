// 노트 댓글 타입 (BRU-62 `note_comments`).
//
// 댓글은 노트가 아니다 — 별도 테이블이고, 앱에서도 `notes` 목록과 절대 섞지 않는다.
// 소프트 삭제가 없다: 지우면 그 자리에서 사라지고, 노트를 영구 삭제하면 cascade로 함께 사라진다.

export interface NoteCommentRow {
  id: string
  note_id: string
  user_id: string
  body: string
  created_at: string
  updated_at: string
}

export interface NoteComment {
  id: string
  noteId: string
  userId: string
  body: string
  createdAt: Date
  updatedAt: Date
  /** 낙관적으로 끼워 넣었고 아직 서버 확인이 오지 않은 댓글 */
  isPending: boolean
}

export function noteCommentRowToNoteComment(row: NoteCommentRow): NoteComment {
  return {
    id: row.id,
    noteId: row.note_id,
    userId: row.user_id,
    body: row.body,
    createdAt: new Date(row.created_at),
    updatedAt: new Date(row.updated_at),
    isPending: false,
  }
}
