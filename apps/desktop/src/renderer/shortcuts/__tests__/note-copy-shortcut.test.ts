import { describe, expect, it } from 'vitest'
import { resolveNoteFeedShortcut } from '../noteFeed'
import type { KeyEventLike } from '../types'

function key(k: string, modifiers: Partial<KeyEventLike> = {}): KeyEventLike {
  return { key: k, metaKey: false, ctrlKey: false, shiftKey: false, altKey: false, ...modifiers }
}

/**
 * 복사 두 갈래 (BRU-104).
 * ⌘C = 내용만, ⌘⇧C = 참조 링크. 맨 `c`는 하위 호환으로 내용 복사에 남는다.
 */
describe('복사 단축키', () => {
  it('맨 c는 지금까지처럼 내용 복사다', () => {
    expect(resolveNoteFeedShortcut(key('c'))).toBe('copyFocused')
    expect(resolveNoteFeedShortcut(key('ㅊ'))).toBe('copyFocused')
  })

  it('⌘C도 내용 복사다', () => {
    expect(resolveNoteFeedShortcut(key('c', { metaKey: true }))).toBe('copyFocused')
    expect(resolveNoteFeedShortcut(key('c', { ctrlKey: true }))).toBe('copyFocused')
  })

  it('⌘⇧C는 참조 링크 복사다', () => {
    expect(resolveNoteFeedShortcut(key('C', { metaKey: true, shiftKey: true }))).toBe(
      'copyFocusedReference'
    )
    expect(resolveNoteFeedShortcut(key('c', { metaKey: true, shiftKey: true }))).toBe(
      'copyFocusedReference'
    )
  })

  it('한글 입력 상태의 ⌘⇧ㅊ도 참조 링크 복사다', () => {
    expect(resolveNoteFeedShortcut(key('ㅊ', { metaKey: true, shiftKey: true }))).toBe(
      'copyFocusedReference'
    )
  })

  it('수식키 없는 Shift+C는 여전히 피드 액션이 아니다 — 댓글 열기의 자리다 (BRU-63)', () => {
    expect(resolveNoteFeedShortcut(key('C', { shiftKey: true }))).toBeNull()
    expect(resolveNoteFeedShortcut(key('ㅊ', { shiftKey: true }))).toBeNull()
  })

  // 맨 ⌥ 조합은 이 해석기 전반이 무시하지 않는 기존 동작이라 여기서 바꾸지 않는다.
  // 새로 만든 ⌘ 갈래 안에서만 ⌥이 섞이면 복사가 아니라고 못 박는다.
  it('⌘⌥C는 복사가 아니다', () => {
    expect(resolveNoteFeedShortcut(key('c', { metaKey: true, altKey: true }))).toBeNull()
    expect(
      resolveNoteFeedShortcut(key('C', { metaKey: true, altKey: true, shiftKey: true }))
    ).toBeNull()
  })
})
