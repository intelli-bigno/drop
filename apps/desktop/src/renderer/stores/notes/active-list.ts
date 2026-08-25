import { noteRowToNote } from '@drop/shared'
import type { Note, NoteRow } from '@drop/shared'

/**
 * 활성 목록(전체 리스트)에 있어야 하는 행인가 (BRU-108).
 *
 * `loadNotes()`는 이 약속을 쿼리로 지킨다 — `.is('deleted_at', null).is('archived_at', null)`.
 * realtime은 행이 그대로 들어오므로 같은 약속을 여기서 지켜야 한다.
 */
function belongsInActiveList(row: NoteRow): boolean {
  return !row.deleted_at && !row.archived_at
}

/**
 * realtime 행 하나를 활성 목록에 반영한다 — 목록에 노트가 드나드는 유일한 관문.
 *
 * INSERT냐 UPDATE냐로 갈라 놓으면 관문이 둘이 되고, 실제로 그래서 보관된 노트가
 * INSERT 경로로 새어 들어왔다. 이벤트 종류가 아니라 **행의 상태**만 보고 판단한다.
 */
export function reconcileActiveList(notes: Note[], row: NoteRow): Note[] {
  if (!belongsInActiveList(row)) {
    return notes.some((n) => n.id === row.id) ? notes.filter((n) => n.id !== row.id) : notes
  }

  if (!notes.some((n) => n.id === row.id)) {
    // realtime에는 연관 데이터(태그·첨부파일)가 실리지 않는다 — 다음 loadNotes()가 채운다
    return [noteRowToNote(row, [], []), ...notes]
  }

  return notes.map((n) =>
    n.id === row.id
      ? {
          ...n,
          content: row.content ?? '',
          updatedAt: new Date(row.updated_at),
          isPinned: row.is_pinned ?? false,
          pinnedAt: row.pinned_at ? new Date(row.pinned_at) : null,
        }
      : n
  )
}
