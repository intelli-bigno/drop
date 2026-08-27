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
 * `loadNotes()`의 정렬 규칙 (BRU-125).
 *
 *   .order('is_pinned',  { ascending: false })
 *   .order('pinned_at',  { ascending: false, nullsFirst: false })
 *   .order('created_at', { ascending: false })
 *
 * 배열이 이 순서를 유지한다는 것에 `NoteFeed`의 날짜 그룹핑이 기대고 있다 —
 * 앞에서부터 훑으며 **직전 그룹과만** 병합하므로, 순서가 깨지면 같은 날짜
 * 헤더가 목록에 두 번 나타난다.
 *
 * 음수면 `a`가 앞이다.
 */
function compareFeedOrder(a: Note, b: Note): number {
  if (a.isPinned !== b.isPinned) return a.isPinned ? -1 : 1

  const aPinned = a.pinnedAt?.getTime() ?? null
  const bPinned = b.pinnedAt?.getTime() ?? null
  if (aPinned !== bPinned) {
    if (aPinned === null) return 1
    if (bPinned === null) return -1
    return bPinned - aPinned
  }

  return b.createdAt.getTime() - a.createdAt.getTime()
}

/** 정렬을 지키는 자리에 끼워 넣는다. 같은 자리면 앞쪽 — 새 노트가 맨 위로 온다. */
function insertInFeedOrder(notes: Note[], note: Note): Note[] {
  const at = notes.findIndex((existing) => compareFeedOrder(note, existing) <= 0)
  if (at === -1) return [...notes, note]
  return [...notes.slice(0, at), note, ...notes.slice(at)]
}

/**
 * 이 행이 저장된 노트보다 뒤처진 소식인가 (BRU-125).
 *
 * 낙관적 생성 경로가 이 상황을 만든다: `createNote('')`가 빈 노트를 목록에 먼저 넣고,
 * 사용자가 타이핑해 `updateNote()`가 반영된 뒤에야 INSERT 에코가 `content: ''`를
 * 싣고 도착한다. 그대로 덮으면 방금 친 글이 화면에서 사라진다.
 *
 * 같은 시각은 뒤처진 것으로 보지 않는다 — 핀 토글처럼 `updated_at`을 올리지 않는
 * 갱신이 있고, 그것까지 버리면 반대쪽 손실이 된다.
 */
function isStale(note: Note, row: NoteRow): boolean {
  return new Date(row.updated_at).getTime() < note.updatedAt.getTime()
}

/**
 * realtime 행 하나를 활성 목록에 반영한다 — 목록에 노트가 드나드는 유일한 관문.
 *
 * INSERT냐 UPDATE냐로 갈라 놓으면 관문이 둘이 되고, 실제로 그래서 보관된 노트가
 * INSERT 경로로 새어 들어왔다 (BRU-108). 이벤트 종류가 아니라 **행의 상태**만 보고
 * 판단한다 — 그 원칙은 BRU-125에서도 유지한다.
 */
export function reconcileActiveList(notes: Note[], row: NoteRow): Note[] {
  // 목록에서 빼는 일은 뒤늦게 도착한 행이라도 해야 한다 — 보관·삭제는 되돌아가지 않는다.
  if (!belongsInActiveList(row)) {
    return notes.some((n) => n.id === row.id) ? notes.filter((n) => n.id !== row.id) : notes
  }

  const existing = notes.find((n) => n.id === row.id)

  if (!existing) {
    // realtime에는 연관 데이터(태그·첨부파일)가 실리지 않는다.
    // 목록에 처음 들어오는 행은 호출부가 loadNotes()로 마저 채운다 — `entersActiveList()` 참고.
    return insertInFeedOrder(notes, noteRowToNote(row, [], []))
  }

  if (isStale(existing, row)) return notes

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

/**
 * 이 행이 목록에 **새로 들어오는가** (BRU-125).
 *
 * 호출부가 태그·첨부를 채우러 `loadNotes()`를 태울지 판단하는 데 쓴다. 관문은 순수
 * 함수로 두고 싶고, 재하이드레이션은 부수효과라 여기서 하지 않는다.
 */
export function entersActiveList(notes: Note[], row: NoteRow): boolean {
  return belongsInActiveList(row) && !notes.some((n) => n.id === row.id)
}

function noteBelongsInActiveList(note: Note): boolean {
  return !note.deletedAt && !note.archivedAt
}

/**
 * 실패 롤백 — 빠진 노트만 피드 순서 제자리에 되넣는다 (BRU-114).
 *
 * 배열 통째 스냅샷을 씌우면 그 사이 realtime·다른 낙관적 갱신이 사라진다.
 * 보관·삭제된 노트는 들이지 않는다. 관문은 여전히 여기 하나다.
 */
export function restoreNoteInList(notes: Note[], note: Note): Note[] {
  if (!noteBelongsInActiveList(note)) return notes
  if (notes.some((n) => n.id === note.id)) return notes
  return insertInFeedOrder(notes, note)
}

/**
 * 실패 롤백 — 아직 목록에 있는 노트만 스냅샷으로 되돌린다 (BRU-114).
 *
 * 그 사이 빠진 노트는 되넣지 않는다. 필드만 고친 낙관적 갱신(프로젝트·반출)의
 * 실패 경로가 쓴다.
 */
export function restoreNoteFields(notes: Note[], note: Note): Note[] {
  if (!notes.some((n) => n.id === note.id)) return notes
  return notes.map((n) => (n.id === note.id ? note : n))
}
