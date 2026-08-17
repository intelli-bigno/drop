// 노트 목록을 부모-자식으로 묶어 피드가 그대로 그릴 행 배열로 만든다 (BRU-70).
//
// 원래 이 로직은 NoteFeed의 useMemo 안에 있었다. 화면 안에 있으면 테스트할 방법이
// 없어서, 부모가 필터에서 빠지면 답글이 통째로 사라지는 버그를 아무도 못 잡았다.
//
// 규칙은 iOS(DropCore.NoteHierarchy, BRU-60)와 같다 — 같은 노트를 두 앱이 다르게
// 보여 주면 어느 쪽이 맞는지 알 수 없다. 다른 것은 들여쓰기 깊이 제한 하나뿐이다:
// iOS는 좁은 화면이라 2단에서 멈추고, 데스크톱은 넓어서 제한하지 않는다.

/** 계층 계산이 실제로 들여다보는 필드만 요구한다 — 테스트가 Note 전체를 만들 필요가 없게 */
export interface HierarchicalNote {
  id: string
  parentId: string | null
  createdAt: Date
}

export interface NoteRow<T extends HierarchicalNote = HierarchicalNote> {
  note: T
  /** 들여쓰기 단수. 0이면 최상위 */
  depth: number
  /** 필터에 걸린 것이 아니라 자식의 맥락을 위해 끌어온 노트 */
  isContextOnly: boolean
  /** 부모가 이 목록에 없어 최상위로 올라온 답글 */
  isOrphanedReply: boolean
}

/**
 * @param visible 필터·검색까지 통과해 실제로 보여야 하는 노트. 이 순서가 최상위 순서가 된다.
 * @param context 같은 뷰(활성/보관/휴지통)의 노트 전부. 부모를 끌어올 후보다.
 *
 * 1. 보이는 답글의 부모는 필터에 걸리지 않아도 끌어온다 — 그러지 않으면 답글이
 *    어느 쪽에도 못 들어가 목록에서 조용히 사라진다(이 이슈의 증상).
 * 2. 부모가 이 뷰에 아예 없으면 답글을 버리지 않고 최상위로 올린다.
 * 3. 형제 답글은 오래된 것부터 — 종전 동작 그대로다.
 */
export function buildNoteRows<T extends HierarchicalNote>(
  visible: T[],
  context: T[]
): Array<NoteRow<T>> {
  if (visible.length === 0) return []

  const byId = new Map<string, T>()
  const order: string[] = []
  for (const note of [...context, ...visible]) {
    if (byId.has(note.id)) continue
    byId.set(note.id, note)
    order.push(note.id)
  }

  const visibleIds = new Set(visible.map((note) => note.id))

  // 규칙 1 — 조상을 맥락으로 끌어온다
  const included = new Set(visibleIds)
  for (const id of visibleIds) {
    const seen = new Set([id])
    let current = byId.get(id)
    while (current?.parentId) {
      const parent = byId.get(current.parentId)
      // 망가진 데이터(순환)에서 멈추지 않으면 무한 루프가 된다
      if (!parent || seen.has(parent.id)) break
      seen.add(parent.id)
      included.add(parent.id)
      current = parent
    }
  }

  // 부모를 따라 올라가다 제자리로 돌아오는 노트를 가려낸다.
  // 자식으로 붙이면 어느 뿌리에서도 닿지 못해 목록에서 사라진다.
  const loops = new Set<string>()
  for (const id of included) {
    const seen = new Set([id])
    let current = byId.get(id)
    while (current?.parentId && included.has(current.parentId)) {
      const parent = byId.get(current.parentId)
      if (!parent) break
      if (seen.has(parent.id)) {
        loops.add(id)
        break
      }
      seen.add(parent.id)
      current = parent
    }
  }

  const childrenByParentId = new Map<string, T[]>()
  const rootIds: string[] = []
  for (const id of order) {
    if (!included.has(id)) continue
    const note = byId.get(id)
    if (!note) continue

    if (note.parentId && !loops.has(id) && included.has(note.parentId)) {
      const siblings = childrenByParentId.get(note.parentId) ?? []
      siblings.push(note)
      childrenByParentId.set(note.parentId, siblings)
    } else {
      rootIds.push(id)
    }
  }

  for (const [parentId, children] of childrenByParentId) {
    childrenByParentId.set(
      parentId,
      [...children].sort((a, b) => a.createdAt.getTime() - b.createdAt.getTime())
    )
  }

  const emitted = new Set<string>()
  const rows: Array<NoteRow<T>> = []

  const emit = (note: T, depth: number): void => {
    if (emitted.has(note.id)) return
    emitted.add(note.id)

    rows.push({
      note,
      depth,
      isContextOnly: !visibleIds.has(note.id),
      // 부모가 있는데 최상위로 나왔다 = 부모를 잃은 답글
      isOrphanedReply: depth === 0 && note.parentId !== null && note.parentId !== note.id,
    })

    for (const child of childrenByParentId.get(note.id) ?? []) {
      emit(child, depth + 1)
    }
  }

  for (const id of rootIds) {
    const note = byId.get(id)
    if (note) emit(note, 0)
  }

  return rows
}
