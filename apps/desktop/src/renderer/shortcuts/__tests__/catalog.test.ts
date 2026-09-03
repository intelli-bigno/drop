import { describe, it, expect } from 'vitest'
import {
  SHORTCUT_CATALOG,
  CHEAT_SHEET_MENU_LABEL,
  CHEAT_SHEET_NOTES,
  displayKeysForEntry,
  formatKeyForDisplay,
  hintForKeyId,
  type ShortcutCatalogEntry,
} from '../catalog'
import { KEYS } from '../keys'
import { resolveNoteFeedShortcut } from '../noteFeed'
import { resolveNoteSelectionShortcut } from '../noteSelection'
import type { KeyEventLike } from '../types'

function key(k: string, mods: Partial<Omit<KeyEventLike, 'key'>> = {}): KeyEventLike {
  return { key: k, metaKey: false, ctrlKey: false, shiftKey: false, altKey: false, ...mods }
}

/** 카탈로그가 적어 둔 수식키를 실제 이벤트 플래그로 옮긴다 (⌘⇧ 조합 포함 — BRU-104). */
function modifiersFor(
  modifier: ShortcutCatalogEntry['modifier']
): Partial<Omit<KeyEventLike, 'key'>> {
  return {
    metaKey: modifier === 'primary' || modifier === 'primary-shift',
    shiftKey: modifier === 'shift' || modifier === 'primary-shift',
  }
}

describe('SHORTCUT_CATALOG', () => {
  it('shouldNotBeEmpty', () => {
    expect(SHORTCUT_CATALOG.length).toBeGreaterThan(0)
  })

  it('shouldDeriveEveryEntryFromTheKeyTable', () => {
    for (const entry of SHORTCUT_CATALOG) {
      expect(KEYS[entry.keyId]).toBeDefined()
    }
  })

  it('shouldHaveNoDuplicateEntriesForTheSameAction', () => {
    const ids = SHORTCUT_CATALOG.map((e) => `${e.group}:${e.keyId}:${e.modifier ?? ''}`)
    expect(new Set(ids).size).toBe(ids.length)
  })

  it('shouldGiveEveryEntryALabelAndGroup', () => {
    for (const entry of SHORTCUT_CATALOG) {
      expect(entry.label.length).toBeGreaterThan(0)
      expect(entry.group.length).toBeGreaterThan(0)
    }
  })

  // 목록이 실제 동작과 어긋나는 것을 막는 핵심 테스트:
  // 피드 항목으로 표시된 키는 실제로 리졸버가 인식해야 한다.
  it('shouldListOnlyKeysThatTheFeedResolverActuallyHandles', () => {
    const feedEntries = SHORTCUT_CATALOG.filter((e) => e.scope === 'feed')
    expect(feedEntries.length).toBeGreaterThan(0)

    for (const entry of feedEntries) {
      for (const k of KEYS[entry.keyId]) {
        const event = key(k, modifiersFor(entry.modifier))
        expect(resolveNoteFeedShortcut(event)).not.toBeNull()
      }
    }
  })

  // BRU-80 — 선택 항목도 같은 방식으로 실제 동작에 묶어 둔다
  it('shouldListOnlyKeysThatTheSelectionResolverActuallyHandles', () => {
    const selectionEntries = SHORTCUT_CATALOG.filter((e) => e.scope === 'selection')
    expect(selectionEntries.length).toBeGreaterThan(0)

    for (const entry of selectionEntries) {
      for (const k of KEYS[entry.keyId]) {
        const event = key(k, { shiftKey: entry.modifier === 'shift' })
        expect(resolveNoteSelectionShortcut(event)).not.toBeNull()
      }
    }
  })

  // BRU-53 — 치트시트는 ⌘/ 와 ? 두 갈래로 나뉜다. 한 항목에 섞어 적으면
  // 화면에 "⌘ / / ?"처럼 나와 맨 `/`도 치트시트를 여는 것처럼 읽힌다.
  it('shouldListTheCheatSheetAsTwoEntriesWithTheirOwnModifiers', () => {
    const primary = SHORTCUT_CATALOG.find((e) => e.keyId === 'cheatSheet')
    const alt = SHORTCUT_CATALOG.find((e) => e.keyId === 'cheatSheetAlt')
    expect(primary?.modifier).toBe('primary')
    expect(KEYS.cheatSheet).toEqual(['/'])
    expect(alt?.modifier).toBeUndefined()
    expect(KEYS.cheatSheetAlt).toEqual(['?'])
  })

  it('shouldMapFeedEntriesToTheActionTheyClaim', () => {
    for (const entry of SHORTCUT_CATALOG.filter((e) => e.scope === 'feed')) {
      const event = key(KEYS[entry.keyId][0], modifiersFor(entry.modifier))
      expect(resolveNoteFeedShortcut(event)).toBe(entry.keyId)
    }
  })

  // BRU-117 — 치트시트 입구는 사용자 메뉴 「단축키」 한 줄. 온보딩 투어·상시 힌트 없음.
  it('shouldExposeAQuietCheatSheetMenuLabel', () => {
    expect(CHEAT_SHEET_MENU_LABEL).toBe('단축키')
  })

  // BRU-133 — 피드 vim식 키는 이미 동작한다. 치트시트가 그것을 빼먹으면 발견성 결함이다.
  it('shouldDocumentFeedVimNavigationAndEditEntry', () => {
    const byId = Object.fromEntries(SHORTCUT_CATALOG.map((e) => [e.keyId, e]))
    expect(KEYS.focusNext).toContain('j')
    expect(KEYS.focusPrev).toContain('k')
    expect(KEYS.enterVisualSelection).toContain('v')
    expect(KEYS.openFocused).toEqual(expect.arrayContaining(['i']))
    expect(byId.focusNext?.group).toBe('탐색')
    expect(byId.focusPrev?.group).toBe('탐색')
    expect(byId.openFocused?.group).toBe('탐색')
    expect(byId.enterVisualSelection?.group).toBe('선택')
  })

  // BRU-213 — 훑는 손의 층이 넷이 됐다. 넷 다 목록에 있어야 발견된다.
  it('shouldDocumentTheWholeScanningLadder', () => {
    const byId = Object.fromEntries(SHORTCUT_CATALOG.map((e) => [e.keyId, e]))
    for (const id of ['focusNext', 'expandFocused', 'openFocused', 'openActions']) {
      expect(byId[id]?.group).toBe('탐색')
    }
    expect(KEYS.expandFocused).toContain('Enter')
    expect(KEYS.openActions).toContain('/')
    // 같은 글쇠가 두 층을 맡으면 하나는 영원히 안 눌린다.
    expect(KEYS.openFocused).not.toContain('/')
  })

  // BRU-133 — 편집기는 마크다운 숏컷 + Esc 끝내기 + Enter 줄바꿈. vim 모달은 없다.
  it('shouldDocumentTheEditorLayerWithoutAVimModal', () => {
    const editor = SHORTCUT_CATALOG.filter((e) => e.group === '편집')
    expect(editor.map((e) => e.keyId).sort()).toEqual([
      'clearFocus',
      'insertLink',
      'insertNewline',
    ])
    expect(editor.every((e) => e.scope === 'editor')).toBe(true)
    expect(KEYS.insertNewline).toEqual(['Enter'])
    const notes = CHEAT_SHEET_NOTES.join(' ')
    expect(notes).toMatch(/마크다운/)
    expect(notes).toMatch(/vim 모드는 없다/)
  })
})

// 「⌘/ 하면 앱의 모든 단축키가 보인다」를 규칙으로 못박는다 (BRU-213).
// 키를 KEYS에 추가하고 카탈로그에 안 적으면 여기서 터진다 — 치트시트가 조용히
// 뒤처지는 유일한 경로를 막는 장치다.
describe('SHORTCUT_CATALOG 완전성 (BRU-213)', () => {
  it('shouldListEveryKeyInTheKeyTable', () => {
    const listed = new Set(SHORTCUT_CATALOG.map((e) => e.keyId))
    const missing = Object.keys(KEYS).filter((id) => !listed.has(id as never))
    expect(missing).toEqual([])
  })

  it('shouldDocumentTheConfirmDialogYesNoKeys', () => {
    const confirm = SHORTCUT_CATALOG.filter((e) => e.scope === 'confirm')
    expect(confirm.map((e) => e.keyId).sort()).toEqual(['confirmNo', 'confirmYes'])
  })
})

describe('hintForKeyId (BRU-213)', () => {
  it('수식키를 기호로 앞에 붙인다', () => {
    expect(hintForKeyId('search')).toBe('⌘O')
    expect(hintForKeyId('openComments')).toBe('⇧C')
    expect(hintForKeyId('copyFocusedReference')).toBe('⌘⇧C')
  })

  it('수식키가 없으면 글쇠 하나만', () => {
    expect(hintForKeyId('togglePin')).toBe('P')
  })

  it('별칭이 여럿이어도 **첫 번째만** 보여 준다 — 버튼 옆 힌트는 한 벌이어야 한다', () => {
    expect(hintForKeyId('archive')).toBe('E')
    expect(hintForKeyId('deleteFocused')).toBe('Delete')
  })

  it('카탈로그에 없는 키는 null', () => {
    expect(hintForKeyId('insertTemplate')).toBe('/')
    expect(hintForKeyId('nope' as never)).toBeNull()
  })
})

describe('formatKeyForDisplay', () => {
  it('shouldRenderArrowKeysAsSymbols', () => {
    expect(formatKeyForDisplay('ArrowDown')).toBe('↓')
    expect(formatKeyForDisplay('ArrowUp')).toBe('↑')
  })

  it('shouldUppercaseSingleLetters', () => {
    expect(formatKeyForDisplay('j')).toBe('J')
  })

  it('shouldLeaveHangulAliasesAsIs', () => {
    expect(formatKeyForDisplay('ㅓ')).toBe('ㅓ')
  })

  it('shouldKeepNamedKeysReadable', () => {
    expect(formatKeyForDisplay('Escape')).toBe('Esc')
    expect(formatKeyForDisplay('Enter')).toBe('Enter')
    expect(formatKeyForDisplay('Backspace')).toBe('Backspace')
  })
})

// BRU-213 — 표에 한글 별칭까지 세 개씩 늘어놓으면 눈이 값을 못 고른다.
// 별칭이 도는 것은 각주 한 줄로 이미 말하고 있다.
describe('displayKeysForEntry', () => {
  const byId = Object.fromEntries(SHORTCUT_CATALOG.map((e) => [e.keyId, e]))

  it('한글 별칭은 표에서 뺀다', () => {
    expect(displayKeysForEntry(byId.focusNext!)).toEqual(['↓', 'J'])
    expect(displayKeysForEntry(byId.copyFocused!)).toEqual(['C'])
  })

  it('보여줄 글쇠를 다 빼지는 않는다 — 어떤 항목도 빈칸으로 서면 안 된다', () => {
    for (const entry of SHORTCUT_CATALOG) {
      expect(displayKeysForEntry(entry).length).toBeGreaterThan(0)
    }
  })

  it('이미 표시용으로 바뀐 이름이다 — 호출부가 다시 포맷하지 않는다', () => {
    expect(displayKeysForEntry(byId.clearFocus!)).toContain('Esc')
    expect(displayKeysForEntry(byId.togglePreview!)).toContain('Space')
  })
})
