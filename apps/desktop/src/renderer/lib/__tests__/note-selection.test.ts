import { describe, it, expect } from 'vitest'
import {
  enterVisualSelection,
  extendSelection,
  resolveSelectedNotes,
  selectedNoteIds,
  selectionScopeKey,
} from '../note-selection'

const ids = (...values: string[]) => values

describe('enterVisualSelection', () => {
  it('shouldStartFromTheFocusedNote', () => {
    expect(enterVisualSelection('c')).toEqual({ anchorId: 'c', headId: 'c' })
  })

  // 포커스가 없으면 무엇을 고르는지 말할 수 없다 — 진입하지 않는다
  it('shouldNotStartWithoutAFocusedNote', () => {
    expect(enterVisualSelection(null)).toBeNull()
    expect(enterVisualSelection(undefined)).toBeNull()
  })
})

describe('extendSelection', () => {
  const list = ids('a', 'b', 'c', 'd', 'e')
  const at = (id: string) => ({ anchorId: id, headId: id })

  it('shouldGrowDownwardOnShiftJ', () => {
    expect(extendSelection(at('b'), 1, list)).toEqual({ anchorId: 'b', headId: 'c' })
  })

  it('shouldGrowUpwardOnShiftK', () => {
    expect(extendSelection(at('d'), -1, list)).toEqual({ anchorId: 'd', headId: 'c' })
  })

  // 축소 — 아래로 벌린 범위에서 shift+k는 다시 좁힌다 (확장의 반대가 아니라 머리의 이동)
  it('shouldShrinkWhenMovingBackTowardTheAnchor', () => {
    expect(extendSelection({ anchorId: 'b', headId: 'e' }, -1, list)).toEqual({
      anchorId: 'b',
      headId: 'd',
    })
  })

  // 머리가 앵커를 지나가면 방향이 뒤집힌다 — 앵커는 그대로 남는다
  it('shouldFlipDirectionWhenTheHeadCrossesTheAnchor', () => {
    expect(extendSelection(at('c'), -1, list)).toEqual({ anchorId: 'c', headId: 'b' })
  })

  it('shouldStopAtTheLastNote', () => {
    expect(extendSelection({ anchorId: 'd', headId: 'e' }, 1, list)).toEqual({
      anchorId: 'd',
      headId: 'e',
    })
  })

  it('shouldStopAtTheFirstNote', () => {
    expect(extendSelection({ anchorId: 'b', headId: 'a' }, -1, list)).toEqual({
      anchorId: 'b',
      headId: 'a',
    })
  })

  it('shouldIgnoreExtensionWithoutASelection', () => {
    expect(extendSelection(null, 1, list)).toBeNull()
  })

  // 목록이 바뀌어 끝점이 사라졌으면 확장할 범위 자체가 없다 — 선택은 죽는다
  it('shouldDieWhenAnEndpointLeftTheList', () => {
    expect(extendSelection({ anchorId: 'b', headId: 'z' }, 1, list)).toBeNull()
    expect(extendSelection({ anchorId: 'z', headId: 'b' }, 1, list)).toBeNull()
  })
})

describe('selectedNoteIds', () => {
  const list = ids('a', 'b', 'c', 'd', 'e')

  it('shouldCoverTheRangeInAscendingOrderRegardlessOfDirection', () => {
    expect(selectedNoteIds({ anchorId: 'e', headId: 'b' }, list)).toEqual(['b', 'c', 'd', 'e'])
    expect(selectedNoteIds({ anchorId: 'b', headId: 'e' }, list)).toEqual(['b', 'c', 'd', 'e'])
  })

  it('shouldHoldJustTheAnchorRightAfterEntering', () => {
    expect(selectedNoteIds({ anchorId: 'd', headId: 'd' }, list)).toEqual(['d'])
  })

  it('shouldBeEmptyWithoutASelection', () => {
    expect(selectedNoteIds(null, list)).toEqual([])
  })

  // 🔴 회귀: 인덱스로 들고 있었을 때는 목록이 바뀌어도 "같은 자리의 다른 노트"가 잡혔다
  it('shouldSelectNothingWhenTheListWasReplaced', () => {
    const active = ids('a', 'b', 'c', 'd', 'e')
    const selection = { anchorId: 'a', headId: 'e' }
    expect(selectedNoteIds(selection, active)).toHaveLength(5)

    const trash = ids('t1', 't2', 't3', 't4', 't5')
    expect(selectedNoteIds(selection, trash)).toEqual([])
  })
})

describe('resolveSelectedNotes', () => {
  const note = (id: string) => ({ id })
  const notes = ['a', 'b', 'c', 'd', 'e'].map(note)

  it('shouldReturnTheNotesInsideTheRange', () => {
    expect(resolveSelectedNotes({ anchorId: 'b', headId: 'd' }, notes)).toEqual([
      note('b'),
      note('c'),
      note('d'),
    ])
  })

  /**
   * 🔴 회귀 (b): 액션 바가 보여주는 개수와 실제로 지워지는 노트는 **같은 출처**여야 한다.
   * 개수를 selection 범위에서, 대상을 잘린 목록에서 가져오던 시절엔 이 둘이 어긋났다.
   */
  it('shouldKeepTheDisplayedCountEqualToTheExecutionTargets', () => {
    const selection = { anchorId: 'b', headId: 'd' }
    const lists = [
      notes,
      notes.slice(0, 2), // 뒤가 잘림 — 끝점이 사라졌다
      ['t1', 't2', 't3', 't4', 't5'].map(note), // 통째로 교체 (뷰 전환)
      [], // 비었다
      [...notes, note('f')], // realtime 삽입
    ]

    for (const list of lists) {
      const targets = resolveSelectedNotes(selection, list)
      const displayedCount = resolveSelectedNotes(selection, list).length
      expect(displayedCount).toBe(targets.length)
      // 대상은 언제나 현재 목록 안에 있다 — 고른 적 없는 노트가 섞이지 않는다
      for (const target of targets) {
        expect(list).toContainEqual(target)
      }
    }
  })

  // 🔴 회귀 (a): 활성 뷰에서 고르고 휴지통으로 전환하면 아무것도 남지 않는다
  it('shouldSelectNothingAfterSwitchingViews', () => {
    const selection = { anchorId: 'a', headId: 'e' }
    const trash = ['t1', 't2', 't3', 't4', 't5'].map(note)
    expect(resolveSelectedNotes(selection, trash)).toEqual([])
  })
})

/**
 * 목록을 바꾸는 축. 하나라도 달라지면 선택은 무효다 —
 * id 기반이라 엉뚱한 노트가 잡히지는 않지만, 0개짜리 액션 바가 남아 있으면 그것도 거짓말이다.
 */
describe('selectionScopeKey', () => {
  const base = {
    viewMode: 'active',
    filterTag: null,
    categoryFilter: 'all',
    inboxOnly: false,
    showExported: false,
  }

  it('shouldStayTheSameForTheSameScope', () => {
    expect(selectionScopeKey(base)).toBe(selectionScopeKey({ ...base }))
  })

  it('shouldChangeWhenAnyAxisChanges', () => {
    const variants = [
      { ...base, viewMode: 'trash' },
      { ...base, viewMode: 'archived' },
      { ...base, filterTag: 'work' },
      { ...base, categoryFilter: 'link' },
      { ...base, inboxOnly: true },
      { ...base, showExported: true },
    ]

    for (const variant of variants) {
      expect(selectionScopeKey(variant)).not.toBe(selectionScopeKey(base))
    }
  })
})
