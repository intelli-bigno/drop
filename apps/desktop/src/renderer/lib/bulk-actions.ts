// 선택 집합에 한 번에 거는 액션 (BRU-80).
// 세트는 iOS SelectionActionBar(BRU-15)와 맞춘다 — 두 앱에서 같은 선택이 같은 일을 해야 한다.

export type BulkViewMode = 'active' | 'archived' | 'trash'

export type BulkActionId =
  | 'tag'
  | 'archive'
  | 'unarchive'
  | 'restore'
  | 'trash'
  | 'deletePermanently'

const ACTIONS_BY_VIEW_MODE: Record<BulkViewMode, BulkActionId[]> = {
  // 태그는 활성 뷰에만 있다 — 보관·휴지통 노트를 분류하는 일은 없다
  active: ['tag', 'archive', 'trash'],
  archived: ['unarchive', 'trash'],
  trash: ['restore', 'deletePermanently'],
}

export function bulkActionsForViewMode(viewMode: BulkViewMode): BulkActionId[] {
  return ACTIONS_BY_VIEW_MODE[viewMode]
}

export function buildBulkDeleteConfirmMessage(
  count: number,
  action: 'trash' | 'deletePermanently'
): string {
  if (action === 'deletePermanently') {
    return `선택한 노트 ${count}개가 영구 삭제됩니다. 복원할 수 없습니다.`
  }
  return `선택한 노트 ${count}개를 휴지통으로 이동합니다.`
}

/**
 * 선택한 노트 **전부**에 달려 있는 태그. 팝오버에서 체크로 보이고 다시 누르면 전부에서 뗀다.
 * 일부에만 달린 태그는 체크하지 않는다 — 누르면 나머지에 붙이는 쪽이 덜 놀랍다.
 */
export function tagIdsOnEveryNote(notes: { tags: { id: string }[] }[]): string[] {
  if (notes.length === 0) return []

  const [first, ...rest] = notes
  return first.tags
    .map((tag) => tag.id)
    .filter((id) => rest.every((note) => note.tags.some((tag) => tag.id === id)))
}
