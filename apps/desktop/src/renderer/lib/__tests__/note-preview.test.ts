// Space 미리보기 패널의 규칙 (BRU-179).
//
// 패널은 **모달이 아니다.** Finder의 Quick Look처럼 열린 채로 j/k가 뒤 목록을
// 계속 움직이고 패널 내용이 따라온다. 그래서 "지금 무엇을 보여줄지"는 패널이
// 따로 기억하지 않는다 — 포커스된 노트가 곧 미리보기 대상이다.
//
// 여기서 지키는 것은 그 규칙과, Space·Escape가 다른 층과 부딪히지 않는 경계다.

import { describe, expect, it } from 'vitest'
import { previewTargetNoteId, resolveEscapeAction, shouldTogglePreview } from '../note-preview'

describe('previewTargetNoteId', () => {
  it('포커스된 노트가 곧 미리보기 대상이다 — 패널이 따로 기억하지 않는다', () => {
    expect(previewTargetNoteId({ isPreviewOpen: true, focusedNoteId: 'n-2' })).toBe('n-2')
  })

  it('포커스가 옮겨가면 대상도 따라간다 (Quick Look처럼)', () => {
    expect(previewTargetNoteId({ isPreviewOpen: true, focusedNoteId: 'n-9' })).toBe('n-9')
  })

  it('닫혀 있으면 대상이 없다', () => {
    expect(previewTargetNoteId({ isPreviewOpen: false, focusedNoteId: 'n-2' })).toBeNull()
  })

  // 포커스가 풀리면 보여줄 것이 없다 — 패널은 마지막 노트를 붙들지 않는다.
  it('포커스가 없으면 열려 있어도 대상이 없다', () => {
    expect(previewTargetNoteId({ isPreviewOpen: true, focusedNoteId: null })).toBeNull()
  })
})

describe('shouldTogglePreview', () => {
  it('포커스된 노트가 있으면 연다', () => {
    expect(shouldTogglePreview({ focusedNoteId: 'n-1', isSelecting: false, isEditing: false })).toBe(
      true
    )
  })

  it('포커스가 없으면 열지 않는다 — 보여줄 노트가 없다', () => {
    expect(shouldTogglePreview({ focusedNoteId: null, isSelecting: false, isEditing: false })).toBe(
      false
    )
  })

  // 편집 중 Space는 글자다. 여기서 패널이 뜨면 띄어쓰기를 못 한다.
  it('편집 중에는 열지 않는다', () => {
    expect(shouldTogglePreview({ focusedNoteId: 'n-1', isSelecting: false, isEditing: true })).toBe(
      false
    )
  })

  // 선택 모드(v)에서 Space는 관용적으로 "선택 토글"의 자리다 (BRU-80).
  // 미리보기가 그 자리를 뺏지 않는다 — 지금은 아무것도 하지 않고 자리를 비워 둔다.
  it('선택 모드에서는 열지 않는다 — Space는 선택의 자리다', () => {
    expect(shouldTogglePreview({ focusedNoteId: 'n-1', isSelecting: true, isEditing: false })).toBe(
      false
    )
  })
})

describe('resolveEscapeAction', () => {
  // Escape 계층 — 패널이 열려 있으면 패널만 닫고 포커스는 남긴다.
  // 한 번에 둘 다 풀리면 훑던 자리를 잃는다.
  it('패널이 열려 있으면 패널만 닫는다', () => {
    expect(resolveEscapeAction({ isPreviewOpen: true })).toBe('close-preview')
  })

  it('패널이 없으면 포커스를 푼다 (기존 동작)', () => {
    expect(resolveEscapeAction({ isPreviewOpen: false })).toBe('clear-focus')
  })
})
