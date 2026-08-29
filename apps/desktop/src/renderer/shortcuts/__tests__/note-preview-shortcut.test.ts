// Space가 피드에서 미리보기를 여는 글쇠라는 것 (BRU-179).
//
// Space는 브라우저에서 기본이 스크롤이고, 편집 중에는 글자다. 그래서 "언제
// 이 글쇠가 우리 것인가"의 경계가 다른 단축키보다 중요하다.

import { describe, expect, it } from 'vitest'
import { resolveNoteFeedShortcut } from '../noteFeed'
import { SHORTCUT_CATALOG, formatKeyForDisplay } from '../catalog'

const key = (over: Partial<Parameters<typeof resolveNoteFeedShortcut>[0]> = {}) => ({
  key: ' ',
  metaKey: false,
  ctrlKey: false,
  shiftKey: false,
  altKey: false,
  ...over,
})

describe('Space — 미리보기 토글', () => {
  it('맨 Space는 미리보기다', () => {
    expect(resolveNoteFeedShortcut(key())).toBe('togglePreview')
  })

  // ⌘Space는 Spotlight, ⌃Space는 입력기 전환이다 — 우리가 가로채면 안 된다.
  it('수식키가 붙으면 우리 것이 아니다', () => {
    expect(resolveNoteFeedShortcut(key({ metaKey: true }))).toBeNull()
    expect(resolveNoteFeedShortcut(key({ ctrlKey: true }))).toBeNull()
    expect(resolveNoteFeedShortcut(key({ altKey: true }))).toBeNull()
    expect(resolveNoteFeedShortcut(key({ shiftKey: true }))).toBeNull()
  })

  // 다른 글쇠를 밀어내지 않았는지 — 회귀 확인
  it('기존 글쇠는 그대로다', () => {
    expect(resolveNoteFeedShortcut(key({ key: 'j' }))).toBe('focusNext')
    expect(resolveNoteFeedShortcut(key({ key: 'k' }))).toBe('focusPrev')
    expect(resolveNoteFeedShortcut(key({ key: 'Escape' }))).toBe('clearFocus')
    expect(resolveNoteFeedShortcut(key({ key: 'i' }))).toBe('openFocused')
  })
})

describe('치트시트 노출', () => {
  // 치트시트는 catalog에서 파생된다. 항목이 없으면 사용자는 이 글쇠의 존재를 알 수 없다.
  it('미리보기가 치트시트에 올라 있다', () => {
    const entry = SHORTCUT_CATALOG.find((e) => e.keyId === 'togglePreview')
    expect(entry).toBeDefined()
    expect(entry?.scope).toBe('feed')
  })

  // ' '를 그대로 그리면 빈 배지가 나온다 — 이름을 붙여야 읽힌다.
  it('Space는 빈 칸이 아니라 이름으로 그려진다', () => {
    expect(formatKeyForDisplay(' ')).toBe('Space')
  })
})
