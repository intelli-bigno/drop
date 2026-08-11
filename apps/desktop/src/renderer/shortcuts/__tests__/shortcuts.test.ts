import { describe, it, expect } from 'vitest'
import { resolveNoteFeedShortcut } from '../noteFeed'
import { resolveNoteEditorShortcut } from '../noteEditor'
import { isCreateNoteShortcut, isSearchShortcut } from '../noteGlobal'
import { isDeleteShortcut, isArchiveShortcut, isRestoreShortcut } from '../noteTrash'
import { isOpenTagListShortcut, isOpenTagManagementShortcut } from '../tagList'
import { isToggleLockShortcut } from '../noteLock'
import type { KeyEventLike } from '../types'

// 데이터화 리팩터링 전 현재 동작을 고정하는 특성 테스트.
// 리팩터링 후에도 이 파일이 그대로 통과해야 한다.
function key(k: string, mods: Partial<Omit<KeyEventLike, 'key'>> = {}): KeyEventLike {
  return { key: k, metaKey: false, ctrlKey: false, shiftKey: false, altKey: false, ...mods }
}

describe('resolveNoteFeedShortcut', () => {
  it('shouldClearFocusOnEscape', () => {
    expect(resolveNoteFeedShortcut(key('Escape'))).toBe('clearFocus')
  })

  it('shouldFocusNextOnDownArrowJAndHangulJ', () => {
    for (const k of ['ArrowDown', 'j', 'ㅓ']) {
      expect(resolveNoteFeedShortcut(key(k))).toBe('focusNext')
    }
  })

  it('shouldFocusPrevOnUpArrowKAndHangulK', () => {
    for (const k of ['ArrowUp', 'k', 'ㅏ']) {
      expect(resolveNoteFeedShortcut(key(k))).toBe('focusPrev')
    }
  })

  it('shouldOpenFocusedOnPlainEnter', () => {
    expect(resolveNoteFeedShortcut(key('Enter'))).toBe('openFocused')
  })

  it('shouldReplyOnShiftEnter', () => {
    expect(resolveNoteFeedShortcut(key('Enter', { shiftKey: true }))).toBe('replyToFocused')
  })

  it('shouldCreateSiblingOnPrimaryEnter', () => {
    expect(resolveNoteFeedShortcut(key('Enter', { metaKey: true }))).toBe('createSibling')
    expect(resolveNoteFeedShortcut(key('Enter', { ctrlKey: true }))).toBe('createSibling')
  })

  it('shouldPreferPrimaryOverShiftOnEnter', () => {
    expect(resolveNoteFeedShortcut(key('Enter', { metaKey: true, shiftKey: true }))).toBe(
      'createSibling'
    )
  })

  it('shouldDeleteOnDeleteAndBackspace', () => {
    expect(resolveNoteFeedShortcut(key('Delete'))).toBe('deleteFocused')
    expect(resolveNoteFeedShortcut(key('Backspace'))).toBe('deleteFocused')
  })

  it('shouldCopyOnCAndHangulC', () => {
    expect(resolveNoteFeedShortcut(key('c'))).toBe('copyFocused')
    expect(resolveNoteFeedShortcut(key('ㅊ'))).toBe('copyFocused')
  })

  it('shouldTogglePinOnPAndHangulP', () => {
    expect(resolveNoteFeedShortcut(key('p'))).toBe('togglePin')
    expect(resolveNoteFeedShortcut(key('ㅔ'))).toBe('togglePin')
  })

  it('shouldSetPriorityOnDigitKeys', () => {
    expect(resolveNoteFeedShortcut(key('0'))).toBe('setPriority0')
    expect(resolveNoteFeedShortcut(key('1'))).toBe('setPriority1')
    expect(resolveNoteFeedShortcut(key('2'))).toBe('setPriority2')
    expect(resolveNoteFeedShortcut(key('3'))).toBe('setPriority3')
  })

  it('shouldReturnNullForUnboundKey', () => {
    expect(resolveNoteFeedShortcut(key('z'))).toBeNull()
    expect(resolveNoteFeedShortcut(key('F5'))).toBeNull()
  })
})

describe('resolveNoteEditorShortcut', () => {
  it('shouldEscapeOnEscape', () => {
    expect(resolveNoteEditorShortcut(key('Escape'))).toBe('escape')
  })

  it('shouldReturnNullOtherwise', () => {
    expect(resolveNoteEditorShortcut(key('Enter'))).toBeNull()
  })
})

describe('global shortcuts', () => {
  it('shouldCreateNoteOnNAndHangulN', () => {
    expect(isCreateNoteShortcut(key('n'))).toBe(true)
    expect(isCreateNoteShortcut(key('ㅜ'))).toBe(true)
    expect(isCreateNoteShortcut(key('m'))).toBe(false)
  })

  it('shouldSearchOnPrimaryK', () => {
    expect(isSearchShortcut(key('k', { metaKey: true }))).toBe(true)
    expect(isSearchShortcut(key('ㅏ', { ctrlKey: true }))).toBe(true)
  })

  it('shouldNotSearchWithoutPrimaryModifier', () => {
    expect(isSearchShortcut(key('k'))).toBe(false)
  })
})

describe('trash shortcuts', () => {
  it('shouldMatchPlainLetterOnly', () => {
    expect(isDeleteShortcut(key('d'))).toBe(true)
    expect(isDeleteShortcut(key('ㅇ'))).toBe(true)
    expect(isArchiveShortcut(key('e'))).toBe(true)
    expect(isArchiveShortcut(key('ㄷ'))).toBe(true)
    expect(isRestoreShortcut(key('r'))).toBe(true)
    expect(isRestoreShortcut(key('ㄱ'))).toBe(true)
  })

  it('shouldNotMatchWithModifiers', () => {
    expect(isDeleteShortcut(key('d', { metaKey: true }))).toBe(false)
    expect(isArchiveShortcut(key('e', { ctrlKey: true }))).toBe(false)
    expect(isRestoreShortcut(key('r', { altKey: true }))).toBe(false)
  })
})

describe('tag shortcuts', () => {
  it('shouldOpenTagListOnPlainT', () => {
    expect(isOpenTagListShortcut(key('t'))).toBe(true)
    expect(isOpenTagListShortcut(key('ㅅ'))).toBe(true)
    expect(isOpenTagListShortcut(key('t', { metaKey: true }))).toBe(false)
  })

  it('shouldOpenTagManagementOnPrimaryT', () => {
    expect(isOpenTagManagementShortcut(key('t', { metaKey: true }))).toBe(true)
    expect(isOpenTagManagementShortcut(key('ㅅ', { ctrlKey: true }))).toBe(true)
    expect(isOpenTagManagementShortcut(key('t'))).toBe(false)
  })
})

describe('lock shortcut', () => {
  it('shouldToggleLockOnMetaL', () => {
    expect(isToggleLockShortcut(key('l', { metaKey: true }))).toBe(true)
    expect(isToggleLockShortcut(key('ㅣ', { metaKey: true }))).toBe(true)
    expect(isToggleLockShortcut(key('l'))).toBe(false)
  })
})
