// vim의 비주얼 모드와 같은 범위 선택 (BRU-80).
//
// 앵커(처음 고른 자리)와 헤드(지금 커서)만 들고 있으면 확장과 축소가 같은 연산이 된다 —
// shift+j는 헤드를 아래로, shift+k는 위로 옮길 뿐이고, 헤드가 앵커 쪽으로 오면 저절로
// 범위가 좁아진다. 선택 집합을 통째로 들고 다니면 이 대칭이 사라진다.

export interface VisualSelection {
  anchorIndex: number
  headIndex: number
}

export function enterVisualSelection(focusedIndex: number | null): VisualSelection | null {
  if (focusedIndex === null) return null
  return { anchorIndex: focusedIndex, headIndex: focusedIndex }
}

export function extendSelection(
  selection: VisualSelection | null,
  direction: 1 | -1,
  maxIndex: number
): VisualSelection | null {
  if (!selection) return null

  const nextHead = Math.min(Math.max(selection.headIndex + direction, 0), maxIndex)
  return { anchorIndex: selection.anchorIndex, headIndex: nextHead }
}

export function selectionBounds(selection: VisualSelection): { start: number; end: number } {
  return {
    start: Math.min(selection.anchorIndex, selection.headIndex),
    end: Math.max(selection.anchorIndex, selection.headIndex),
  }
}

export function selectedIndexes(selection: VisualSelection | null): number[] {
  if (!selection) return []

  const { start, end } = selectionBounds(selection)
  const indexes: number[] = []
  for (let i = start; i <= end; i++) indexes.push(i)
  return indexes
}

export function isIndexSelected(selection: VisualSelection | null, index: number): boolean {
  if (!selection) return false

  const { start, end } = selectionBounds(selection)
  return index >= start && index <= end
}

export function selectionCount(selection: VisualSelection | null): number {
  if (!selection) return 0

  const { start, end } = selectionBounds(selection)
  return end - start + 1
}
