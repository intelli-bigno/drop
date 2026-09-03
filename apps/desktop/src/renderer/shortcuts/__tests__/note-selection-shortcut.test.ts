import { describe, it, expect } from 'vitest'
import { resolveNoteSelectionShortcut, resolveFeedEscape } from '../noteSelection'
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

// Esc 한 번이 무엇을 벗기는지 (BRU-109).
// 전역 keydown 경로에서 Esc가 선택 해제에만 쓰이고 포커스 해제로는 내려가지 못하던
// 자리를 순수 함수로 끌어내 못 박는다.
describe('resolveFeedEscape', () => {
  const state = (over: Partial<Parameters<typeof resolveFeedEscape>[0]> = {}) => ({
    isConfirmDialogOpen: false,
    isActionBarOpen: false,
    hasSelection: false,
    isExpanded: false,
    hasFocus: false,
    ...over,
  })

  // 확인 다이얼로그가 떠 있으면 Esc는 다이얼로그의 것이다 —
  // 선택만 풀면 "0개 삭제" 문구가 남은 채 확인해도 아무것도 안 지워진다.
  it('shouldYieldToTheConfirmDialog', () => {
    expect(resolveFeedEscape(state({ isConfirmDialogOpen: true, hasSelection: true }))).toBe(
      'ignore'
    )
    expect(resolveFeedEscape(state({ isConfirmDialogOpen: true, hasFocus: true }))).toBe('ignore')
  })

  it('shouldClearTheSelectionFirst', () => {
    expect(resolveFeedEscape(state({ hasSelection: true, hasFocus: true }))).toBe('clearSelection')
  })

  // 회귀: 선택이 없는 Esc는 포커스를 풀어야 한다. 전역 경로가 여기서 끊겨 있었다.
  it('shouldClearTheFocusWhenNothingIsSelected', () => {
    expect(resolveFeedEscape(state({ hasFocus: true }))).toBe('clearFocus')
  })

  it('shouldDoNothingWhenThereIsNeitherSelectionNorFocus', () => {
    expect(resolveFeedEscape(state())).toBe('none')
  })

  // BRU-213 — Esc는 한 번에 한 겹씩 벗긴다. 액션 줄 → 선택 → 펼침 → 포커스.
  // 한 번에 다 풀리면 훑던 자리를 잃고, 층이 뒤바뀌면 안 연 것부터 닫힌다.
  it('shouldCloseTheActionBarBeforeAnythingElse', () => {
    expect(
      resolveFeedEscape(state({ isActionBarOpen: true, isExpanded: true, hasFocus: true }))
    ).toBe('closeActionBar')
    expect(
      resolveFeedEscape(state({ isActionBarOpen: true, hasSelection: true, hasFocus: true }))
    ).toBe('closeActionBar')
  })

  it('shouldCollapseBeforeLettingGoOfTheFocus — 접히기도 전에 포커스를 잃으면 훑던 자리가 사라진다', () => {
    expect(resolveFeedEscape(state({ isExpanded: true, hasFocus: true }))).toBe('collapse')
  })

  it('shouldStillClearTheFocusOnceNothingIsOpen', () => {
    expect(resolveFeedEscape(state({ hasFocus: true }))).toBe('clearFocus')
  })

  // 확인 다이얼로그는 여전히 가장 세다 — 그 위에 아무것도 없다.
  it('shouldYieldToTheConfirmDialogEvenWithTheActionBarOpen', () => {
    expect(
      resolveFeedEscape(state({ isConfirmDialogOpen: true, isActionBarOpen: true }))
    ).toBe('ignore')
  })
})
