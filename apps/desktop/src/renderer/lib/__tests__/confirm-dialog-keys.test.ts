import { describe, expect, it } from 'vitest'
import { initialFocus, resolveConfirmDialogKey } from '../confirm-dialog-keys'

const key = (key: string, modifiers: Partial<KeyboardEvent> = {}) =>
  ({ key, metaKey: false, ctrlKey: false, altKey: false, shiftKey: false, ...modifiers }) as const

describe('resolveConfirmDialogKey', () => {
  it('y를 누르면 승낙한다', () => {
    expect(resolveConfirmDialogKey(key('y'))).toBe('confirm')
  })

  it('n을 누르면 거절한다', () => {
    expect(resolveConfirmDialogKey(key('n'))).toBe('cancel')
  })

  it('Escape는 지금까지처럼 거절이다', () => {
    expect(resolveConfirmDialogKey(key('Escape'))).toBe('cancel')
  })

  it('대문자로 와도 같게 본다 — Shift가 눌려도 승낙·거절이다', () => {
    expect(resolveConfirmDialogKey(key('Y', { shiftKey: true }))).toBe('confirm')
    expect(resolveConfirmDialogKey(key('N', { shiftKey: true }))).toBe('cancel')
  })

  it('한글 입력 상태의 같은 물리 키도 받는다', () => {
    expect(resolveConfirmDialogKey(key('ㅛ'))).toBe('confirm')
    expect(resolveConfirmDialogKey(key('ㅜ'))).toBe('cancel')
  })

  it('⌘·⌃·⌥가 붙으면 우리 것이 아니다', () => {
    expect(resolveConfirmDialogKey(key('y', { metaKey: true }))).toBeNull()
    expect(resolveConfirmDialogKey(key('y', { ctrlKey: true }))).toBeNull()
    expect(resolveConfirmDialogKey(key('n', { altKey: true }))).toBeNull()
  })

  it('Escape는 수식키가 붙으면 무시한다 — ⌥Esc 같은 OS 조합과 겹치지 않게', () => {
    expect(resolveConfirmDialogKey(key('Escape', { metaKey: true }))).toBeNull()
  })

  it('그 밖의 키는 다이얼로그가 관여하지 않는다', () => {
    expect(resolveConfirmDialogKey(key('Enter'))).toBeNull()
    expect(resolveConfirmDialogKey(key('Tab'))).toBeNull()
    expect(resolveConfirmDialogKey(key('d'))).toBeNull()
  })
})

// BRU-54를 되돌리는 것이 아니라 **조건을 붙이는** 것이다 (BRU-213).
// 되돌릴 수 있는 삭제(휴지통으로)는 Enter로 끝나야 한다 — Delete 누르고 Enter가
// 손에 붙은 흐름이다. 되돌릴 수 없는 것은 그대로 취소에 선다.
describe('initialFocus', () => {
  it('되돌릴 수 있으면 승낙에 선다 — Delete 다음 Enter로 끝난다', () => {
    expect(initialFocus({ reversible: true })).toBe('confirm')
  })

  it('되돌릴 수 없으면 취소에 선다 — 두 번 눌러서 사라지면 안 되는 것들이다', () => {
    expect(initialFocus({ reversible: false })).toBe('cancel')
  })

  it('말이 없으면 안전한 쪽이다 — 새 다이얼로그가 실수로 파괴적 기본값을 갖지 않게', () => {
    expect(initialFocus({})).toBe('cancel')
  })
})
