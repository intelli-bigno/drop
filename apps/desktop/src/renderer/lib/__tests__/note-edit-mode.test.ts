import { describe, it, expect } from 'vitest'
import { isEditorOpen, resolveNoteCardView, toggleExpandedNote } from '../note-edit-mode'

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

// BRU-213 — 눌러서 펼친다. BRU-179가 막은 것은 **포커스**가 펼치는 것이었다:
// j/k로 훑을 때마다 카드가 열리면 행 높이가 뛰어 훑기가 망가진다. 클릭은 다르다 —
// 훑는 동작이 아니라 "이걸 보겠다"는 한 번의 결정이라, 그 자리에서 열려도 된다.
describe('클릭으로 펼치기 (BRU-213)', () => {
  it('펼친 것으로 표시된 카드는 viewer다', () => {
    expect(resolveNoteCardView({ isFocused: false, isEditing: false, isExpanded: true })).toBe(
      'viewer'
    )
  })

  it('포커스만으로는 여전히 안 펼쳐진다 — BRU-179는 그대로다', () => {
    expect(resolveNoteCardView({ isFocused: true, isEditing: false, isExpanded: false })).toBe(
      'one-line'
    )
  })

  it('펼친 카드에서 편집에 들어가면 editor가 이긴다', () => {
    expect(resolveNoteCardView({ isFocused: true, isEditing: true, isExpanded: true })).toBe(
      'editor'
    )
  })

  it('일괄 펼치기는 개별 상태와 무관하게 편다', () => {
    expect(
      resolveNoteCardView({ isFocused: false, isEditing: false, isExpanded: false, expandAll: true })
    ).toBe('viewer')
  })
})

describe('toggleExpandedNote', () => {
  it('닫힌 것을 누르면 열린다', () => {
    expect(toggleExpandedNote(null, 'a')).toBe('a')
  })

  it('열린 것을 다시 누르면 닫힌다 — 같은 자리를 두 번 누르면 되돌아와야 한다', () => {
    expect(toggleExpandedNote('a', 'a')).toBeNull()
  })

  it('다른 것을 누르면 그것만 열린다 — 한 번에 하나여야 목록이 목록으로 남는다', () => {
    expect(toggleExpandedNote('a', 'b')).toBe('b')
  })
})
