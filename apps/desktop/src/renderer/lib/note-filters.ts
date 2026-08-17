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
  /** Linear로 반출된 노트의 이슈 URL. null이면 아직 반출되지 않았다 (BRU-45) */
  linearIssueUrl?: string | null
}

export interface NoteFilterOptions {
  /** 이 이름의 태그가 붙은 노트만 */
  filterTag: string | null
  /** 링크·미디어·파일 중 하나만 (null·'all'은 전체) */
  categoryFilter: CategoryFilter
  /** Inbox — 태그가 하나도 없는 노트만 (BRU-50) */
  inboxOnly?: boolean
  /** 반출된 노트도 함께 보기 (기본은 숨김, BRU-45) */
  showExported?: boolean
  /**
   * Inbox에서 방금 태그가 붙었지만 아직 자리를 지켜야 하는 노트들.
   * 태그 팝오버가 열려 있는 동안 그 노트가 목록에서 빠지면 팝오버가 허공에 뜬다.
   * 방금 반출한 노트도 같은 이유로 여기에 들어온다 — 눈앞에서 줄이 사라지면
   * 무슨 일이 일어났는지 알 수 없다.
   */
  retainedNoteIds?: ReadonlySet<string>
}

/** Inbox의 정의 — 태그가 하나도 없는 노트. 새 컬럼도, 마이그레이션도 없다. */
export function isUntaggedNote(note: Pick<FilterableNote, 'tags'>): boolean {
  return note.tags.length === 0
}

/**
 * 반출의 정의 — Linear 이슈 URL이 붙어 있는 노트 (BRU-45).
 *
 * 태그(`linear`)로 판정하지 않는다. 태그는 사람이 손으로 붙였다 뗐다 하는 것이고,
 * URL은 실제로 이슈가 만들어졌을 때만 채워진다 — 어긋나면 URL이 사실이다.
 */
export function isExportedNote(note: Pick<FilterableNote, 'linearIssueUrl'>): boolean {
  return !!note.linearIssueUrl
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
  {
    filterTag,
    categoryFilter,
    inboxOnly = false,
    showExported = false,
    retainedNoteIds,
  }: NoteFilterOptions
): T[] {
  return notes.filter(
    (note) =>
      matchesTag(note, filterTag) &&
      matchesCategory(note, categoryFilter) &&
      matchesInbox(note, inboxOnly, retainedNoteIds) &&
      matchesExport(note, showExported, retainedNoteIds)
  )
}

/**
 * 반출된 노트는 기본 목록에서 빠진다 — 처리가 끝난 노트가 계속 보이면
 * 같은 것을 두 번 처리하게 된다. 이것이 이 기능의 핵심이다.
 *
 * 태그·카테고리 필터가 걸려 있어도 마찬가지다. "work 태그를 보는 중"이라고
 * 반출된 것까지 되살아나면 숨김 규칙을 믿을 수 없게 된다.
 */
function matchesExport(
  note: FilterableNote,
  showExported: boolean,
  retainedNoteIds: ReadonlySet<string> | undefined
): boolean {
  if (showExported) return true
  return !isExportedNote(note) || (retainedNoteIds?.has(note.id) ?? false)
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
  notes: Array<Pick<FilterableNote, 'parentId' | 'tags' | 'linearIssueUrl'>>
): number {
  return notes.filter(
    // 반출된 노트는 태그가 없어도 처리가 끝난 것이다 — Inbox 수에서 뺀다 (BRU-45).
    (note) => note.parentId === null && isUntaggedNote(note) && !isExportedNote(note)
  ).length
}
