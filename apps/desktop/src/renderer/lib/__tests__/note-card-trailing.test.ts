import { describe, it, expect } from 'vitest'
import {
  resolveTrailingSlot,
  shouldPinStatusStayVisible,
  reservedActionsWidth,
  ACTION_BUTTON_SIZE,
} from '../note-card-trailing'

describe('resolveTrailingSlot', () => {
  it('should show the time when the pointer is away', () => {
    expect(resolveTrailingSlot({ isHovered: false })).toBe('time')
  })

  it('should show the actions when the pointer is over the card', () => {
    expect(resolveTrailingSlot({ isHovered: true })).toBe('actions')
  })
})

describe('shouldPinStatusStayVisible', () => {
  it('should hide the status icons when nothing is pinned or locked', () => {
    expect(shouldPinStatusStayVisible({ isPinned: false, isLocked: false })).toBe(false)
  })

  it('should keep the status icons for a pinned note', () => {
    expect(shouldPinStatusStayVisible({ isPinned: true, isLocked: false })).toBe(true)
  })

  it('should keep the status icons for a locked note', () => {
    expect(shouldPinStatusStayVisible({ isPinned: false, isLocked: true })).toBe(true)
  })
})

describe('reservedActionsWidth', () => {
  // BRU-57 — 액션이 태그를 덮지 않으려면 액션이 들어갈 자리를 미리 비워 둬야 한다.
  it('should reserve room for every action the active view can show', () => {
    // 고정·잠금·답글·프로젝트·댓글·기록·보관·삭제 = 8개 (프로젝트는 BRU-83에서 늘었다)
    expect(reservedActionsWidth('active')).toBe(8 * ACTION_BUTTON_SIZE + 7 * 2)
  })

  it('should reserve less room in views with fewer actions', () => {
    expect(reservedActionsWidth('archived')).toBe(2 * ACTION_BUTTON_SIZE + 2)
    expect(reservedActionsWidth('trash')).toBe(2 * ACTION_BUTTON_SIZE + 2)
  })

  // BRU-46 — 줄 폭이 버튼 수에 따라 흔들리면 안 된다. 예약 폭은 실제로 그려진
  // 버튼 수가 아니라 보기 모드가 정하므로, 같은 목록의 카드는 모두 같은 값을 받는다.
  it('should not depend on how many buttons a particular card renders', () => {
    expect(reservedActionsWidth('active')).toBe(reservedActionsWidth('active'))
    expect(reservedActionsWidth('active')).toBeGreaterThan(reservedActionsWidth('trash'))
  })
})
