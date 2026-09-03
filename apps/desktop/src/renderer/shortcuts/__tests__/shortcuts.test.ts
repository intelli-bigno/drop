import { describe, it, expect } from 'vitest'
import { resolveNoteFeedShortcut } from '../noteFeed'
import { resolveNoteEditorShortcut } from '../noteEditor'
import {
  isCreateNoteShortcut,
  isSearchShortcut,
  isCheatSheetShortcut,
  isToggleThemeShortcut,
} from '../noteGlobal'
import { isDeleteShortcut, isArchiveShortcut, isRestoreShortcut } from '../noteTrash'
import { isOpenTagListShortcut, isOpenTagManagementShortcut } from '../tagList'
import { isToggleLockShortcut } from '../noteLock'
import { KEYS } from '../keys'
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

  // BRU-53 — 맨 Enter로는 **편집이** 열리지 않는다. BRU-213에서 맨 Enter가
  // 펼쳐 읽기를 맡았지만 그 규칙은 그대로다: 읽으려고 펼치는 것과 고치려고
  // 들어가는 것은 다른 층이고, 훑던 손이 실수로 편집에 빠지면 안 된다.
  it('shouldNotOpenEditorOnPlainEnter', () => {
    expect(resolveNoteFeedShortcut(key('Enter'))).not.toBe('openFocused')
  })

  // BRU-213 — `/`는 액션 줄로 넘어갔고 편집 진입은 `i` 하나가 됐다.
  it('shouldOpenFocusedOnIAndHangulI', () => {
    for (const k of ['i', 'ㅑ']) {
      expect(resolveNoteFeedShortcut(key(k))).toBe('openFocused')
    }
  })

  // ⌘/ 는 치트시트다 — 액션 줄도 편집도 열면 안 된다
  it('shouldNotResolveOnPrimarySlash', () => {
    expect(resolveNoteFeedShortcut(key('/', { metaKey: true }))).toBeNull()
    expect(resolveNoteFeedShortcut(key('/', { ctrlKey: true }))).toBeNull()
  })

  it('shouldNotOpenFocusedWhenModifiersAreHeld', () => {
    expect(resolveNoteFeedShortcut(key('i', { metaKey: true }))).toBeNull()
    expect(resolveNoteFeedShortcut(key('i', { shiftKey: true }))).toBeNull()
    expect(resolveNoteFeedShortcut(key('i', { altKey: true }))).toBeNull()
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

  it('shouldSearchOnPrimaryO', () => {
    expect(isSearchShortcut(key('o', { metaKey: true }))).toBe(true)
    expect(isSearchShortcut(key('ㅐ', { ctrlKey: true }))).toBe(true)
  })

  it('shouldNotSearchWithoutPrimaryModifier', () => {
    expect(isSearchShortcut(key('o'))).toBe(false)
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

describe('cheat sheet shortcut', () => {
  it('shouldOpenOnPrimarySlash', () => {
    expect(isCheatSheetShortcut(key('/', { metaKey: true }))).toBe(true)
    expect(isCheatSheetShortcut(key('/', { ctrlKey: true }))).toBe(true)
  })

  it('shouldOpenOnQuestionMarkWithoutModifier', () => {
    expect(isCheatSheetShortcut(key('?'))).toBe(true)
  })

  it('shouldNotOpenOnPlainSlash', () => {
    expect(isCheatSheetShortcut(key('/'))).toBe(false)
  })

  // BRU-53 — 맨 `/`는 편집 진입 키가 됐다. 키 표에서도 치트시트가 그것을 주장하면 안 된다.
  it('shouldNotClaimBareSlashInTheKeyTable', () => {
    expect(KEYS.cheatSheetAlt).not.toContain('/')
    expect(KEYS.cheatSheet).toEqual(['/'])
  })
})

// BRU-213 — 라이트↔다크를 글쇠 한 벌로. 지우는 키와 한 겹 차이로 두지 않는 것이 요점이다.
describe('theme toggle shortcut', () => {
  it('shouldToggleOnPrimaryShiftD', () => {
    expect(isToggleThemeShortcut(key('D', { metaKey: true, shiftKey: true }))).toBe(true)
    expect(isToggleThemeShortcut(key('D', { ctrlKey: true, shiftKey: true }))).toBe(true)
  })

  it('shouldToggleWhileHangulInputIsOn', () => {
    expect(isToggleThemeShortcut(key('ㅇ', { metaKey: true, shiftKey: true }))).toBe(true)
  })

  it('shouldNotFireWithoutShift — ⌘D는 비어 있지만 여기가 잡지 않는다', () => {
    expect(isToggleThemeShortcut(key('D', { metaKey: true }))).toBe(false)
    expect(isToggleThemeShortcut(key('d', { metaKey: true }))).toBe(false)
  })

  it('shouldNotCollideWithTrashDelete — 맨 d는 휴지통의 삭제다', () => {
    expect(isToggleThemeShortcut(key('d'))).toBe(false)
    expect(isToggleThemeShortcut(key('D', { shiftKey: true }))).toBe(false)
  })
})

// BRU-213 — 목록을 훑는 손의 층을 다시 나눈다.
//   ↑↓/JK 훑기 → Enter 펼치기 → i 편집 → / 액션 고르기 → Esc 한 겹씩 되돌리기
describe('feed keyboard layers (BRU-213)', () => {
  it('shouldExpandOnPlainEnter', () => {
    expect(resolveNoteFeedShortcut(key('Enter'))).toBe('expandFocused')
  })

  it('shouldKeepEnterModifiersAsNoteCreation — 펼치기가 만들기를 빼앗지 않는다', () => {
    expect(resolveNoteFeedShortcut(key('Enter', { metaKey: true }))).toBe('createSibling')
    expect(resolveNoteFeedShortcut(key('Enter', { shiftKey: true }))).toBe('replyToFocused')
  })

  it('shouldOpenActionsOnSlash', () => {
    expect(resolveNoteFeedShortcut(key('/'))).toBe('openActions')
  })

  it('shouldEnterEditOnIOnly — `/`는 이제 액션 줄의 것이다', () => {
    expect(resolveNoteFeedShortcut(key('i'))).toBe('openFocused')
    expect(resolveNoteFeedShortcut(key('ㅑ'))).toBe('openFocused')
    expect(KEYS.openFocused).not.toContain('/')
  })

  it('shouldNotOpenActionsWithModifiers — ⌘/는 치트시트다', () => {
    expect(resolveNoteFeedShortcut(key('/', { metaKey: true }))).toBe(null)
    expect(resolveNoteFeedShortcut(key('/', { ctrlKey: true }))).toBe(null)
  })
})

// BRU-213 — 검색은 ⌘K와 ⌘O 둘 다로 연다. 한 동작에 글쇠가 둘일 뿐,
// 항목이 둘이 되는 것은 아니다 (치트시트에 「검색」이 두 줄로 서면 안 된다).
describe('search shortcut', () => {
  it('shouldOpenOnPrimaryO', () => {
    expect(isSearchShortcut(key('o', { metaKey: true }))).toBe(true)
    expect(isSearchShortcut(key('o', { ctrlKey: true }))).toBe(true)
  })

  it('shouldOpenWhileHangulInputIsOn', () => {
    expect(isSearchShortcut(key('ㅐ', { metaKey: true }))).toBe(true)
  })

  it('shouldNotOpenWithoutTheModifier — 맨 o는 글자다', () => {
    expect(isSearchShortcut(key('o'))).toBe(false)
  })

  // ⌘K는 편집기의 링크 걸기로 넘어갔다 (BRU-213). 한 글쇠가 두 층을 맡으면
  // 하나는 영원히 안 눌린다 — 검색 핸들러는 창 전역이라 편집 중에도 먼저 먹는다.
  it('shouldNotClaimPrimaryK — 그 자리는 링크 걸기의 것이다', () => {
    expect(isSearchShortcut(key('k', { metaKey: true }))).toBe(false)
    expect(isSearchShortcut(key('ㅏ', { metaKey: true }))).toBe(false)
    expect(KEYS.search).not.toContain('k')
    expect(KEYS.insertLink).toContain('k')
  })
})
