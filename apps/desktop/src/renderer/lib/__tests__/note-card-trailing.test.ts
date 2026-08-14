import { describe, it, expect } from 'vitest'
import { resolveTrailingSlot, shouldPinStatusStayVisible } from '../note-card-trailing'

describe('resolveTrailingSlot', () => {
  it('should show the time when the card is idle', () => {
    expect(resolveTrailingSlot({ isHovered: false, isFocused: false })).toBe('time')
  })

  it('should show the actions when the pointer is over the card', () => {
    expect(resolveTrailingSlot({ isHovered: true, isFocused: false })).toBe('actions')
  })

  it('should show the actions when the card has keyboard focus', () => {
    expect(resolveTrailingSlot({ isHovered: false, isFocused: true })).toBe('actions')
  })

  it('should show the actions when hovered and focused at once', () => {
    expect(resolveTrailingSlot({ isHovered: true, isFocused: true })).toBe('actions')
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
