import { describe, it, expect } from 'vitest'
import { isEditorOpen } from '../note-edit-mode'

describe('isEditorOpen', () => {
  it('shouldOpenWhenCardIsFocused', () => {
    expect(isEditorOpen({ isFocused: true })).toBe(true)
  })

  it('shouldStayClosedWhenCardIsNotFocused', () => {
    expect(isEditorOpen({ isFocused: false })).toBe(false)
  })
})
