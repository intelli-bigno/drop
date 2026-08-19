import { describe, it, expect } from 'vitest'
import {
  enterVisualSelection,
  extendSelection,
  isIndexSelected,
  selectedIndexes,
  selectionCount,
} from '../note-selection'

describe('enterVisualSelection', () => {
  it('shouldStartFromTheFocusedNote', () => {
    expect(enterVisualSelection(3)).toEqual({ anchorIndex: 3, headIndex: 3 })
  })

  // 포커스가 없으면 무엇을 고르는지 말할 수 없다 — 진입하지 않는다
  it('shouldNotStartWithoutAFocusedNote', () => {
    expect(enterVisualSelection(null)).toBeNull()
  })
})

describe('extendSelection', () => {
  const at = (index: number) => ({ anchorIndex: index, headIndex: index })

  it('shouldGrowDownwardOnShiftJ', () => {
    expect(extendSelection(at(2), 1, 9)).toEqual({ anchorIndex: 2, headIndex: 3 })
  })

  it('shouldGrowUpwardOnShiftK', () => {
    expect(extendSelection(at(5), -1, 9)).toEqual({ anchorIndex: 5, headIndex: 4 })
  })

  // 축소 — 아래로 벌린 범위에서 shift+k는 다시 좁힌다 (확장의 반대가 아니라 머리의 이동)
  it('shouldShrinkWhenMovingBackTowardTheAnchor', () => {
    const widened = { anchorIndex: 2, headIndex: 5 }
    expect(extendSelection(widened, -1, 9)).toEqual({ anchorIndex: 2, headIndex: 4 })
  })

  // 머리가 앵커를 지나가면 방향이 뒤집힌다 — 앵커는 그대로 남는다
  it('shouldFlipDirectionWhenTheHeadCrossesTheAnchor', () => {
    const collapsed = { anchorIndex: 3, headIndex: 3 }
    expect(extendSelection(collapsed, -1, 9)).toEqual({ anchorIndex: 3, headIndex: 2 })
  })

  it('shouldStopAtTheLastNote', () => {
    expect(extendSelection({ anchorIndex: 8, headIndex: 9 }, 1, 9)).toEqual({
      anchorIndex: 8,
      headIndex: 9,
    })
  })

  it('shouldStopAtTheFirstNote', () => {
    expect(extendSelection({ anchorIndex: 1, headIndex: 0 }, -1, 9)).toEqual({
      anchorIndex: 1,
      headIndex: 0,
    })
  })

  it('shouldIgnoreExtensionWithoutASelection', () => {
    expect(extendSelection(null, 1, 9)).toBeNull()
  })
})

describe('selectedIndexes', () => {
  it('shouldCoverTheRangeInAscendingOrderRegardlessOfDirection', () => {
    expect(selectedIndexes({ anchorIndex: 5, headIndex: 2 })).toEqual([2, 3, 4, 5])
    expect(selectedIndexes({ anchorIndex: 2, headIndex: 5 })).toEqual([2, 3, 4, 5])
  })

  it('shouldHoldJustTheAnchorRightAfterEntering', () => {
    expect(selectedIndexes({ anchorIndex: 4, headIndex: 4 })).toEqual([4])
  })

  it('shouldBeEmptyWithoutASelection', () => {
    expect(selectedIndexes(null)).toEqual([])
  })
})

describe('isIndexSelected', () => {
  it('shouldIncludeBothEnds', () => {
    const selection = { anchorIndex: 5, headIndex: 2 }
    expect(isIndexSelected(selection, 2)).toBe(true)
    expect(isIndexSelected(selection, 5)).toBe(true)
    expect(isIndexSelected(selection, 1)).toBe(false)
    expect(isIndexSelected(selection, 6)).toBe(false)
  })

  it('shouldSelectNothingWithoutASelection', () => {
    expect(isIndexSelected(null, 0)).toBe(false)
  })
})

describe('selectionCount', () => {
  it('shouldCountTheWholeRange', () => {
    expect(selectionCount({ anchorIndex: 2, headIndex: 5 })).toBe(4)
    expect(selectionCount({ anchorIndex: 5, headIndex: 5 })).toBe(1)
    expect(selectionCount(null)).toBe(0)
  })
})
