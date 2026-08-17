import { describe, it, expect } from 'vitest'
import { isEditorOpen } from '../note-edit-mode'

describe('isEditorOpen', () => {
  it('shouldOpenWhenFocusedCardEntersEditMode', () => {
    expect(isEditorOpen({ isFocused: true, isEditing: true })).toBe(true)
  })

  // BRU-53 — 포커스만으로는 펼치지 않는다. j/k/클릭은 한 줄을 유지한다.
  it('shouldStayClosedWhenOnlyFocused', () => {
    expect(isEditorOpen({ isFocused: true, isEditing: false })).toBe(false)
  })

  it('shouldStayClosedWhenNotFocused', () => {
    expect(isEditorOpen({ isFocused: false, isEditing: false })).toBe(false)
  })

  // 포커스를 잃은 카드는 편집 플래그가 남아 있어도 닫혀 있어야 한다
  it('shouldStayClosedWhenEditingButNotFocused', () => {
    expect(isEditorOpen({ isFocused: false, isEditing: true })).toBe(false)
  })
})
