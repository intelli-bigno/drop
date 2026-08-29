// 활성 노트 목록에 걸리는 필터들의 순수 규칙.
//
// NoteFeed 안에 useMemo로 흩어져 있던 판정을 한곳으로 모은 것이다.
// 렌더링을 거치지 않고 테스트할 수 있어야 필터가 하나 늘 때마다
// 조합(태그 × 카테고리)을 눈으로 확인하는 일을 그만둘 수 있다.

export type CategoryFilter = 'all' | 'link' | 'media' | 'files' | null

/**
 * 할일 필터 (BRU-175).
 *
 * `null` = 걸러내지 않음, `todo` = 할일 전부(끝난 것 포함), `open` = 아직 안 끝난 것만.
 * 끝난 할일을 기본으로 숨기지 않는 이유는 `countOpenTodos` 주석 참조.
 */
export type TodoFilter = 'todo' | 'open' | null

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
  /** 이 노트가 속한 프로젝트. null이면 미분류 (BRU-83) */
  projectId?: string | null
  /** 노트의 종류 (BRU-175). 없으면 일반 노트로 본다 */
  type?: 'note' | 'todo'
  /** 할일을 끝낸 시각 (BRU-175). null이면 미완료 */
  completedAt?: Date | null
}

/**
 * "아직 프로젝트가 없는 노트만" 을 고르는 값 (BRU-83).
 *
 * null은 이미 "프로젝트로 걸러내지 않음"이라 미분류를 표현할 자리가 없다.
 * UUID와 겹치지 않는 문자열이면 프로젝트 id와 섞일 일이 없다.
 */
export const UNASSIGNED_PROJECT_ID = '__unassigned__'

export interface NoteFilterOptions {
  /** 이 이름의 태그가 붙은 노트만 */
  filterTag: string | null
  /** 링크·미디어·파일 중 하나만 (null·'all'은 전체) */
  categoryFilter: CategoryFilter
  /**
   * 이 프로젝트의 노트만. null이면 걸러내지 않고,
   * UNASSIGNED_PROJECT_ID면 아직 프로젝트가 없는 노트만 (BRU-83)
   */
  filterProjectId?: string | null
  /** Inbox — 태그가 하나도 없는 노트만 (BRU-50) */
  inboxOnly?: boolean
  /** 반출된 노트도 함께 보기 (기본은 숨김, BRU-45) */
  showExported?: boolean
  /** 할일만 보기 (BRU-175). null이면 걸러내지 않는다 */
  todoFilter?: TodoFilter
  /**
   * Inbox에서 방금 태그가 붙었지만 아직 자리를 지켜야 하는 노트들.
   * 태그 팝오버가 열려 있는 동안 그 노트가 목록에서 빠지면 팝오버가 허공에 뜬다.
   * 방금 반출한 노트도 같은 이유로 여기에 들어온다 — 눈앞에서 줄이 사라지면
   * 무슨 일이 일어났는지 알 수 없다.
   */
  retainedNoteIds?: ReadonlySet<string>
}

/** 태그가 하나도 붙지 않은 노트. 이름 그대로 **태그만** 본다. */
export function isUntaggedNote(note: Pick<FilterableNote, 'tags'>): boolean {
  return note.tags.length === 0
}

/**
 * Inbox의 정의 — **아직 분류되지 않은** 노트 (BRU-50, BRU-181로 개정).
 *
 * 원래는 "태그가 하나도 없는 노트"였다. 그런데 에이전트가 판정 결과를 `agent:task`
 * 태그로 남기고 있어서, 할일로 분류하는 순간 그 노트가 Inbox에서 사라졌다 —
 * "할일로 분류됨"과 "정리 끝남"이 같은 신호가 돼 버린 것이다.
 *
 * BRU-175로 `type` 컬럼이 생겼으니 분류를 태그에 얹지 않아도 된다. 그러면 반대로
 * "할일인데 태그가 없어서 Inbox에 영영 남는" 문제가 생기는데, **할일로 표시하는
 * 것 자체가 분류 행위**라고 보면 답이 나온다. "이건 해야 할 일이다"라고 판정된
 * 노트는 더 이상 아직 분류되지 않은 캡처가 아니다.
 *
 * 그래서 타입 축이 태그 축과 나란히 들어온다. 덕분에 drop-loop이 `agent:task`를
 * 그만 붙여도 그 노트들이 Inbox로 되돌아오지 않는다.
 */
export function isUnclassifiedNote(note: Pick<FilterableNote, 'tags' | 'type'>): boolean {
  return isUntaggedNote(note) && !isTodoNote(note)
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

/**
 * 프로젝트 필터 (BRU-83).
 *
 * 유예(retainedNoteIds)를 여기서도 본다 — 미분류만 보다가 프로젝트를 고르는 순간
 * 줄이 사라지면 무슨 일이 일어났는지 알 수 없다. 태그·반출과 같은 규칙이다.
 */
function matchesProject(
  note: FilterableNote,
  filterProjectId: string | null,
  retainedNoteIds: ReadonlySet<string> | undefined
): boolean {
  if (!filterProjectId) return true
  if (retainedNoteIds?.has(note.id)) return true
  const projectId = note.projectId ?? null
  if (filterProjectId === UNASSIGNED_PROJECT_ID) return projectId === null
  return projectId === filterProjectId
}

/**
 * 할일인가 (BRU-175).
 *
 * 완료 시각이 아니라 **타입**이 기준이다. DB CHECK(notes_todo_state_consistent)가
 * 일반 노트에 완료 시각이 남는 조합을 막지만, 제약이 한 겹 뚫려도 그 노트가
 * 할일 목록에 끼어들면 안 된다.
 */
export function isTodoNote(note: Pick<FilterableNote, 'type'>): boolean {
  return note.type === 'todo'
}

/** 끝난 할일인가 (BRU-175) */
export function isCompletedTodo(note: Pick<FilterableNote, 'type' | 'completedAt'>): boolean {
  return isTodoNote(note) && !!note.completedAt
}

function matchesTodo(note: FilterableNote, todoFilter: TodoFilter): boolean {
  if (!todoFilter) return true
  if (!isTodoNote(note)) return false
  // 'todo'는 끝난 것까지 포함한다 — 무엇을 했는지 함께 보는 것이 목록의 쓸모다
  return todoFilter === 'todo' || !isCompletedTodo(note)
}

function matchesInbox(
  note: FilterableNote,
  inboxOnly: boolean,
  retainedNoteIds: ReadonlySet<string> | undefined
): boolean {
  if (!inboxOnly) return true
  return isUnclassifiedNote(note) || (retainedNoteIds?.has(note.id) ?? false)
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
    filterProjectId = null,
    inboxOnly = false,
    showExported = false,
    todoFilter = null,
    retainedNoteIds,
  }: NoteFilterOptions
): T[] {
  return notes.filter(
    (note) =>
      matchesTag(note, filterTag) &&
      matchesCategory(note, categoryFilter) &&
      matchesProject(note, filterProjectId, retainedNoteIds) &&
      matchesInbox(note, inboxOnly, retainedNoteIds) &&
      matchesTodo(note, todoFilter) &&
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
 * Inbox 뱃지에 띄울 수 — 아직 분류되지 않은 **최상위** 노트 수 (BRU-181).
 *
 * 답글은 세지 않는다. 피드는 최상위 노트만 줄로 세우고 답글은 그 아래에
 * 딸려 나오므로, 최상위만 세야 화면에 보이는 줄 수와 맞는다.
 *
 * 유예(retainedNoteIds)는 반영하지 않는다 — 태그를 붙이는 순간 숫자가 줄어드는
 * 것이 이 기능의 핵심이다. 줄은 팝오버가 닫힐 때까지 남아 있어도 숫자는 먼저 준다.
 */
export function countInboxNotes(
  notes: Array<Pick<FilterableNote, 'parentId' | 'tags' | 'type' | 'linearIssueUrl'>>
): number {
  return notes.filter(
    // 반출된 노트는 태그가 없어도 처리가 끝난 것이다 — Inbox 수에서 뺀다 (BRU-45).
    (note) => note.parentId === null && isUnclassifiedNote(note) && !isExportedNote(note)
  ).length
}

/**
 * 할일 뱃지에 띄울 수 — **아직 끝나지 않은 최상위** 할일 수 (BRU-175).
 *
 * 끝난 할일은 목록에서는 흐리게 남지만 숫자에서는 빠진다. 숫자는 "남은 일이
 * 몇 개인가"에 답해야 하고, 목록은 "무엇을 했나"까지 보여 주는 것이 쓸모다 —
 * 둘의 질문이 다르므로 답도 다르다.
 *
 * 답글을 세지 않는 것도, 반출된 것을 빼는 것도 countInboxNotes와 같은 규칙이다.
 */
export function countOpenTodos(
  notes: Array<Pick<FilterableNote, 'parentId' | 'type' | 'completedAt' | 'linearIssueUrl'>>
): number {
  return notes.filter(
    (note) =>
      note.parentId === null &&
      isTodoNote(note) &&
      !isCompletedTodo(note) &&
      !isExportedNote(note)
  ).length
}
