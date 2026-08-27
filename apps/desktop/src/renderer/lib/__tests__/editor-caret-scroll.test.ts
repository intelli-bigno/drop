import { describe, it, expect } from 'vitest'
import { applyCaretScroll, computeCaretScrollTop } from '../editor-caret-scroll'

const viewport = {
  currentScrollTop: 100,
  viewportHeight: 200,
}

describe('computeCaretScrollTop', () => {
  it('shouldNotScrollWhenCaretIsFullyVisible', () => {
    expect(
      computeCaretScrollTop({
        ...viewport,
        caretOffsetTop: 120,
        caretHeight: 20,
      })
    ).toBe(100)
  })

  it('shouldScrollUpWhenCaretIsAboveTheViewport', () => {
    expect(
      computeCaretScrollTop({
        ...viewport,
        caretOffsetTop: 40,
        caretHeight: 20,
      })
    ).toBe(40)
  })

  it('shouldScrollDownWhenCaretIsBelowTheViewport', () => {
    // 캐럿 하단 340 > 보이는 하단 300 → 340-200 = 140
    expect(
      computeCaretScrollTop({
        ...viewport,
        caretOffsetTop: 320,
        caretHeight: 20,
      })
    ).toBe(140)
  })

  it('shouldNeverReturnNegativeScrollTop', () => {
    expect(
      computeCaretScrollTop({
        currentScrollTop: 10,
        viewportHeight: 200,
        caretOffsetTop: -8,
        caretHeight: 20,
      })
    ).toBe(0)
  })

  it('shouldLeaveScrollUnchangedWhenViewportHasNoHeight', () => {
    expect(
      computeCaretScrollTop({
        currentScrollTop: 50,
        viewportHeight: 0,
        caretOffsetTop: 400,
        caretHeight: 20,
      })
    ).toBe(50)
  })
})

describe('applyCaretScroll', () => {
  it('shouldWriteTheComputedScrollTopOntoTheContainer', () => {
    const container = { scrollTop: 0, clientHeight: 200 }
    applyCaretScroll(container, { offsetTop: 250, height: 20 })
    expect(container.scrollTop).toBe(70)
  })

  it('shouldNotTouchScrollTopWhenTheCaretIsAlreadyVisible', () => {
    const container = { scrollTop: 40, clientHeight: 200 }
    applyCaretScroll(container, { offsetTop: 80, height: 20 })
    expect(container.scrollTop).toBe(40)
  })
})
