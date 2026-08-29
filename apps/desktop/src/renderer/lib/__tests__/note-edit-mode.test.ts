import { describe, it, expect } from 'vitest'
import { isEditorOpen, resolveNoteCardView } from '../note-edit-mode'

describe('isEditorOpen', () => {
  it('shouldOpenWhenFocusedCardEntersEditMode', () => {
    expect(isEditorOpen({ isFocused: true, isEditing: true })).toBe(true)
  })

  // BRU-53 — 포커스만으로는 편집이 열리지 않는다. `/`·`i`를 눌러야 한다.
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

  // BRU-79 — 일괄 펼치기는 에디터를 여는 기능이 아니다. N개의 Lexical이
  // 한꺼번에 마운트되면 BRU-66(직렬화가 원문을 덮어씀)이 N배로 재발한다.
  it('shouldStayClosedWhenExpandedInBulk', () => {
    expect(isEditorOpen({ isFocused: false, isEditing: false, expandAll: true })).toBe(false)
    expect(isEditorOpen({ isFocused: true, isEditing: false, expandAll: true })).toBe(false)
  })
})

describe('resolveNoteCardView', () => {
  it('shouldStayOnOneLineWhenIdle', () => {
    expect(resolveNoteCardView({ isFocused: false, isEditing: false })).toBe('one-line')
  })

  // BRU-179 — 포커스는 이제 펼치지 않는다. 훑는 동작(j/k)마다 카드가 열리면
  // 행 높이가 38px→77px로 뛰고 본문 글자가 55px 왼쪽·한 줄 아래로 이동해
  // 훑기 자체가 망가진다(실측). 본문을 보는 길은 Space 미리보기 패널로 옮겼다.
  // BRU-59가 세운 "읽기는 읽기 전용 viewer로" 원칙은 그 패널이 이어받는다.
  it('shouldStayOnOneLineWhenOnlyFocused', () => {
    expect(resolveNoteCardView({ isFocused: true, isEditing: false })).toBe('one-line')
  })

  // BRU-66 재발 방지의 핵심 — 포커스만으로는 절대 editor가 되지 않는다.
  it('shouldNeverOpenTheEditorFromFocusAlone', () => {
    expect(resolveNoteCardView({ isFocused: true, isEditing: false })).not.toBe('editor')
  })

  it('shouldShowEditorOnlyWhenFocusedAndEditing', () => {
    expect(resolveNoteCardView({ isFocused: true, isEditing: true })).toBe('editor')
  })

  it('shouldFallBackToOneLineWhenEditingButNotFocused', () => {
    expect(resolveNoteCardView({ isFocused: false, isEditing: true })).toBe('one-line')
  })

  // BRU-79 — 일괄 펼치기는 포커스 없는 카드도 viewer로 편다.
  it('shouldShowViewerForEveryCardWhenExpandedInBulk', () => {
    expect(resolveNoteCardView({ isFocused: false, isEditing: false, expandAll: true })).toBe(
      'viewer'
    )
  })

  // 편집 중인 카드는 일괄 토글에 휘둘리지 않는다 — 쓰던 글이 사라지면 안 된다.
  it('shouldKeepTheEditorOpenWhileBulkExpanded', () => {
    expect(resolveNoteCardView({ isFocused: true, isEditing: true, expandAll: true })).toBe('editor')
  })

  // 토글을 끄면 포커스가 없는 카드는 한 줄로 돌아온다 (기본 = 접힘).
  it('shouldCollapseBackWhenBulkExpandIsTurnedOff', () => {
    expect(resolveNoteCardView({ isFocused: false, isEditing: false, expandAll: false })).toBe(
      'one-line'
    )
  })
})
