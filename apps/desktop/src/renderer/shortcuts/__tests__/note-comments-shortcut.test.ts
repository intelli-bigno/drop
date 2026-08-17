import { describe, it, expect } from 'vitest'
import { isOpenCommentsShortcut } from '../noteComments'
import { resolveNoteFeedShortcut } from '../noteFeed'
import { SHORTCUT_CATALOG } from '../catalog'
import { KEYS } from '../keys'
import type { KeyEventLike } from '../types'

function key(k: string, mods: Partial<Omit<KeyEventLike, 'key'>> = {}): KeyEventLike {
  return { key: k, metaKey: false, ctrlKey: false, shiftKey: false, altKey: false, ...mods }
}

// 댓글 진입키는 Shift+C 다.
// `c`(내용 복사)를 그대로 두면서 "Comment"의 첫 글자를 쓰려면 수식키가 필요하고,
// ⌘C는 OS 복사라 못 쓴다. Shift+Enter(답글)·⌘T(태그 관리)와 같은 결이다.
describe('isOpenCommentsShortcut', () => {
  it('shouldOpenCommentsOnShiftC', () => {
    expect(isOpenCommentsShortcut(key('C', { shiftKey: true }))).toBe(true)
  })

  it('shouldOpenCommentsOnShiftHangulC', () => {
    expect(isOpenCommentsShortcut(key('ㅊ', { shiftKey: true }))).toBe(true)
  })

  it('shouldNotFireWithoutShift', () => {
    expect(isOpenCommentsShortcut(key('c'))).toBe(false)
    expect(isOpenCommentsShortcut(key('ㅊ'))).toBe(false)
  })

  it('shouldNotFireWithPrimaryModifier — ⌘C·⌘⇧C 는 OS 복사다', () => {
    expect(isOpenCommentsShortcut(key('C', { shiftKey: true, metaKey: true }))).toBe(false)
    expect(isOpenCommentsShortcut(key('C', { shiftKey: true, ctrlKey: true }))).toBe(false)
    expect(isOpenCommentsShortcut(key('C', { shiftKey: true, altKey: true }))).toBe(false)
  })

  // 충돌 회귀 방지 — 맨 `c`는 여전히 내용 복사여야 한다
  it('shouldLeavePlainCAsCopyFocused', () => {
    expect(resolveNoteFeedShortcut(key('c'))).toBe('copyFocused')
    expect(resolveNoteFeedShortcut(key('ㅊ'))).toBe('copyFocused')
  })

  // 피드 리졸버가 Shift+C를 복사로 잘못 집으면 댓글 대신 복사가 된다
  it('shouldNotBeSwallowedByTheFeedResolver', () => {
    expect(resolveNoteFeedShortcut(key('C', { shiftKey: true }))).toBeNull()
  })

  // 한글 입력 상태에서 Shift+ㅊ는 `ㅊ` 그대로 찍힌다 — 피드 리졸버가 이걸
  // 복사로 집으면 댓글을 열 때마다 클립보드가 덮인다.
  it('shouldNotCopyOnShiftHangulC', () => {
    expect(resolveNoteFeedShortcut(key('ㅊ', { shiftKey: true }))).toBeNull()
  })
})

describe('댓글 단축키 치트시트 반영', () => {
  it('shouldAppearInTheCatalogWithShiftModifier', () => {
    const entry = SHORTCUT_CATALOG.find((e) => e.keyId === 'openComments')
    expect(entry).toBeDefined()
    expect(entry?.modifier).toBe('shift')
    expect(entry?.label).toContain('댓글')
  })

  it('shouldDeclareItsKeysInTheKeyTable', () => {
    expect(KEYS.openComments).toEqual(['C', 'ㅊ'])
  })
})
