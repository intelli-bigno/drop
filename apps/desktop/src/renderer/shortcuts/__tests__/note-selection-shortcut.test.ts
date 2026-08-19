import { describe, it, expect } from 'vitest'
import { resolveNoteSelectionShortcut } from '../noteSelection'
import { resolveNoteFeedShortcut } from '../noteFeed'
import type { KeyEventLike } from '../types'

function key(k: string, mods: Partial<Omit<KeyEventLike, 'key'>> = {}): KeyEventLike {
  return { key: k, metaKey: false, ctrlKey: false, shiftKey: false, altKey: false, ...mods }
}

describe('resolveNoteSelectionShortcut', () => {
  it('shouldEnterVisualSelectionOnV', () => {
    expect(resolveNoteSelectionShortcut(key('v'))).toBe('enterVisual')
  })

  // 한글 입력 상태에서도 같은 물리 키가 먹어야 한다
  it('shouldEnterVisualSelectionOnTheHangulAlias', () => {
    expect(resolveNoteSelectionShortcut(key('ㅍ'))).toBe('enterVisual')
  })

  it('shouldExtendDownOnShiftJ', () => {
    expect(resolveNoteSelectionShortcut(key('J', { shiftKey: true }))).toBe('extendNext')
    expect(resolveNoteSelectionShortcut(key('ㅓ', { shiftKey: true }))).toBe('extendNext')
  })

  it('shouldExtendUpOnShiftK', () => {
    expect(resolveNoteSelectionShortcut(key('K', { shiftKey: true }))).toBe('extendPrev')
    expect(resolveNoteSelectionShortcut(key('ㅏ', { shiftKey: true }))).toBe('extendPrev')
  })

  it('shouldClearTheSelectionOnEscape', () => {
    expect(resolveNoteSelectionShortcut(key('Escape'))).toBe('exitVisual')
  })

  // 맨 j/k는 포커스 이동이지 선택 확장이 아니다
  it('shouldIgnorePlainJAndK', () => {
    expect(resolveNoteSelectionShortcut(key('j'))).toBeNull()
    expect(resolveNoteSelectionShortcut(key('k'))).toBeNull()
  })

  // ⌘K는 검색이다 — 선택이 가로채면 안 된다
  it('shouldIgnoreModifiedKeys', () => {
    expect(resolveNoteSelectionShortcut(key('K', { shiftKey: true, metaKey: true }))).toBeNull()
    expect(resolveNoteSelectionShortcut(key('v', { metaKey: true }))).toBeNull()
    expect(resolveNoteSelectionShortcut(key('v', { altKey: true }))).toBeNull()
  })

  it('shouldIgnoreUnrelatedKeys', () => {
    expect(resolveNoteSelectionShortcut(key('a'))).toBeNull()
    expect(resolveNoteSelectionShortcut(key('Enter', { shiftKey: true }))).toBeNull()
  })
})

// 두 리졸버가 같은 키를 두고 다투면 한 번의 키 입력이 두 가지 일을 한다.
describe('selection and feed resolvers', () => {
  it('shouldNotBothClaimShiftJOrShiftK', () => {
    for (const k of ['J', 'K', 'ㅓ', 'ㅏ']) {
      const event = key(k, { shiftKey: true })
      expect(resolveNoteSelectionShortcut(event)).not.toBeNull()
      expect(resolveNoteFeedShortcut(event)).toBeNull()
    }
  })

  it('shouldLeavePlainJAndKToTheFeedResolver', () => {
    expect(resolveNoteFeedShortcut(key('j'))).toBe('focusNext')
    expect(resolveNoteSelectionShortcut(key('j'))).toBeNull()
  })

  // Esc는 둘 다 반응한다 — 선택이 있으면 선택만 풀고, 없으면 포커스가 풀린다.
  // 우선순위는 화면 쪽에서 정하고, 여기서는 둘 다 Esc를 안다는 사실만 못 박는다.
  it('shouldBothKnowEscape', () => {
    expect(resolveNoteSelectionShortcut(key('Escape'))).toBe('exitVisual')
    expect(resolveNoteFeedShortcut(key('Escape'))).toBe('clearFocus')
  })
})
