import { describe, it, expect } from 'vitest'
import { SHORTCUT_CATALOG, formatKeyForDisplay } from '../catalog'
import { KEYS } from '../keys'
import { resolveNoteFeedShortcut } from '../noteFeed'
import type { KeyEventLike } from '../types'

function key(k: string, mods: Partial<Omit<KeyEventLike, 'key'>> = {}): KeyEventLike {
  return { key: k, metaKey: false, ctrlKey: false, shiftKey: false, altKey: false, ...mods }
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
        const event = key(k, {
          metaKey: entry.modifier === 'primary',
          shiftKey: entry.modifier === 'shift',
        })
        expect(resolveNoteFeedShortcut(event)).not.toBeNull()
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
      const event = key(KEYS[entry.keyId][0], {
        metaKey: entry.modifier === 'primary',
        shiftKey: entry.modifier === 'shift',
      })
      expect(resolveNoteFeedShortcut(event)).toBe(entry.keyId)
    }
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
