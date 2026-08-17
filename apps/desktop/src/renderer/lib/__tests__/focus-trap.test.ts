import { describe, it, expect } from 'vitest'
import { FOCUSABLE_SELECTOR, nextFocusIndex } from '../focus-trap'

describe('nextFocusIndex', () => {
  it('shouldMoveToTheNextElementOnTab', () => {
    expect(nextFocusIndex({ count: 3, currentIndex: 0, shiftKey: false })).toBe(1)
    expect(nextFocusIndex({ count: 3, currentIndex: 1, shiftKey: false })).toBe(2)
  })

  // 트랩의 핵심 — 마지막에서 Tab을 눌러도 다이얼로그 밖으로 나가지 않는다
  it('shouldWrapToTheFirstElementFromTheLastOne', () => {
    expect(nextFocusIndex({ count: 3, currentIndex: 2, shiftKey: false })).toBe(0)
  })

  it('shouldMoveBackwardsOnShiftTab', () => {
    expect(nextFocusIndex({ count: 3, currentIndex: 2, shiftKey: true })).toBe(1)
  })

  it('shouldWrapToTheLastElementFromTheFirstOne', () => {
    expect(nextFocusIndex({ count: 3, currentIndex: 0, shiftKey: true })).toBe(2)
  })

  // 포커스가 이미 다이얼로그 밖으로 새어 나간 상태(currentIndex -1)에서도 되돌려 잡는다
  it('shouldPullFocusBackInsideWhenItIsOutside', () => {
    expect(nextFocusIndex({ count: 3, currentIndex: -1, shiftKey: false })).toBe(0)
    expect(nextFocusIndex({ count: 3, currentIndex: -1, shiftKey: true })).toBe(2)
  })

  it('shouldStayPutWhenThereIsOnlyOneFocusableElement', () => {
    expect(nextFocusIndex({ count: 1, currentIndex: 0, shiftKey: false })).toBe(0)
    expect(nextFocusIndex({ count: 1, currentIndex: 0, shiftKey: true })).toBe(0)
  })

  it('shouldReportNoTargetWhenNothingIsFocusable', () => {
    expect(nextFocusIndex({ count: 0, currentIndex: -1, shiftKey: false })).toBe(-1)
  })
})

describe('FOCUSABLE_SELECTOR', () => {
  it('shouldMatchButtonsAndLinksAndFields', () => {
    expect(FOCUSABLE_SELECTOR).toContain('button')
    expect(FOCUSABLE_SELECTOR).toContain('a[href]')
    expect(FOCUSABLE_SELECTOR).toContain('input')
  })

  // disabled 버튼과 tabindex="-1"은 Tab 순환에 끼면 안 된다
  it('shouldExcludeDisabledAndUntabbableElements', () => {
    expect(FOCUSABLE_SELECTOR).toContain(':not([disabled])')
    expect(FOCUSABLE_SELECTOR).toContain('[tabindex]:not([tabindex="-1"])')
  })
})
