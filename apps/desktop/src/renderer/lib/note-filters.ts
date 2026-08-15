// 활성 노트 목록에 걸리는 필터들의 순수 규칙.
//
// NoteFeed 안에 useMemo로 흩어져 있던 판정을 한곳으로 모은 것이다.
// 렌더링을 거치지 않고 테스트할 수 있어야 필터가 하나 늘 때마다
// 조합(태그 × 카테고리)을 눈으로 확인하는 일을 그만둘 수 있다.

export type CategoryFilter = 'all' | 'link' | 'media' | 'files' | null

/** 필터가 실제로 들여다보는 필드만 요구한다 — 테스트가 Note 전체를 만들 필요가 없게 */
export interface FilterableNote {
  id: string
  parentId: string | null
  tags: Array<{ name: string }>
  hasLink: boolean
  hasMedia: boolean
  hasFiles: boolean
}

export interface NoteFilterOptions {
  /** 이 이름의 태그가 붙은 노트만 */
  filterTag: string | null
  /** 링크·미디어·파일 중 하나만 (null·'all'은 전체) */
  categoryFilter: CategoryFilter
  /** Inbox — 태그가 하나도 없는 노트만 (BRU-50) */
  inboxOnly?: boolean
  /**
   * Inbox에서 방금 태그가 붙었지만 아직 자리를 지켜야 하는 노트들.
   * 태그 팝오버가 열려 있는 동안 그 노트가 목록에서 빠지면 팝오버가 허공에 뜬다.
   */
  retainedNoteIds?: ReadonlySet<string>
}

/** Inbox의 정의 — 태그가 하나도 없는 노트. 새 컬럼도, 마이그레이션도 없다. */
export function isUntaggedNote(note: Pick<FilterableNote, 'tags'>): boolean {
  return note.tags.length === 0
}

function matchesCategory(note: FilterableNote, categoryFilter: CategoryFilter): boolean {
  if (categoryFilter === 'link') return note.hasLink
  if (categoryFilter === 'media') return note.hasMedia
  if (categoryFilter === 'files') return note.hasFiles
  return true
}

function matchesTag(note: FilterableNote, filterTag: string | null): boolean {
  if (!filterTag) return true
  return note.tags.some((t) => t.name === filterTag)
}

function matchesInbox(
  note: FilterableNote,
  inboxOnly: boolean,
  retainedNoteIds: ReadonlySet<string> | undefined
): boolean {
  if (!inboxOnly) return true
  return isUntaggedNote(note) || (retainedNoteIds?.has(note.id) ?? false)
}

/**
 * 활성 노트 목록에 필터를 모두 적용한다 (AND).
 *
 * 원래 순서를 유지한다 — 정렬·그룹화는 피드가 따로 한다.
 */
export function applyNoteFilters<T extends FilterableNote>(
  notes: T[],
  { filterTag, categoryFilter, inboxOnly = false, retainedNoteIds }: NoteFilterOptions
): T[] {
  return notes.filter(
    (note) =>
      matchesTag(note, filterTag) &&
      matchesCategory(note, categoryFilter) &&
      matchesInbox(note, inboxOnly, retainedNoteIds)
  )
}

/**
 * Inbox 뱃지에 띄울 수 — 태그 없는 **최상위** 노트 수.
 *
 * 답글은 세지 않는다. 피드는 최상위 노트만 줄로 세우고 답글은 그 아래에
 * 딸려 나오므로, 최상위만 세야 화면에 보이는 줄 수와 맞는다.
 *
 * 유예(retainedNoteIds)는 반영하지 않는다 — 태그를 붙이는 순간 숫자가 줄어드는
 * 것이 이 기능의 핵심이다. 줄은 팝오버가 닫힐 때까지 남아 있어도 숫자는 먼저 준다.
 */
export function countInboxNotes(
  notes: Array<Pick<FilterableNote, 'parentId' | 'tags'>>
): number {
  return notes.filter((note) => note.parentId === null && isUntaggedNote(note)).length
}
