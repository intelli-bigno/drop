// 노트 편집 히스토리 타입.
// 기록은 DB 트리거(snapshot_note_content)가 하고, 앱은 읽기·복원만 한다.

export interface NoteRevisionRow {
  id: string
  note_id: string
  content: string
  created_at: string
}

export interface NoteRevision {
  id: string
  noteId: string
  content: string
  createdAt: Date
}

export function noteRevisionRowToNoteRevision(row: NoteRevisionRow): NoteRevision {
  return {
    id: row.id,
    noteId: row.note_id,
    content: row.content,
    createdAt: new Date(row.created_at),
  }
}

const SUMMARY_MAX_LENGTH = 120

/** 히스토리 목록에 한 줄로 보여줄 요약 */
export function summarizeRevision(content: string): string {
  const collapsed = content.replace(/\s+/g, ' ').trim()
  if (collapsed === '') return '(빈 노트)'
  if (collapsed.length <= SUMMARY_MAX_LENGTH) return collapsed
  return `${collapsed.slice(0, SUMMARY_MAX_LENGTH)}…`
}
