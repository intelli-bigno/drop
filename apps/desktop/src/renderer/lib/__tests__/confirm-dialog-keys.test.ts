import { describe, expect, it } from 'vitest'
import { resolveConfirmDialogKey } from '../confirm-dialog-keys'

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
