import { describe, expect, it } from 'vitest'
import {
  DEFAULT_SETTINGS,
  parseSettings,
  serializeSettings,
  withQuickCaptureShortcut,
  withShortcutNoticeSuppressed,
} from './settings'

describe('parseSettings', () => {
  it('returns the defaults when nothing has been saved yet', () => {
    expect(parseSettings(null)).toEqual(DEFAULT_SETTINGS)
    expect(parseSettings('')).toEqual(DEFAULT_SETTINGS)
  })

  it('returns the defaults instead of throwing on corrupt JSON', () => {
    expect(parseSettings('{ not json')).toEqual(DEFAULT_SETTINGS)
  })

  it('returns the defaults when the payload is not an object', () => {
    expect(parseSettings('"a string"')).toEqual(DEFAULT_SETTINGS)
    expect(parseSettings('null')).toEqual(DEFAULT_SETTINGS)
  })

  it('keeps a stored quick capture shortcut, normalized', () => {
    expect(parseSettings('{"quickCaptureShortcut":"cmd+shift+k"}')).toEqual({
      ...DEFAULT_SETTINGS,
      quickCaptureShortcut: 'Command+Shift+K',
    })
  })

  it('drops a stored shortcut that is no longer valid', () => {
    expect(parseSettings('{"quickCaptureShortcut":"Space"}')).toEqual(DEFAULT_SETTINGS)
    expect(parseSettings('{"quickCaptureShortcut":42}')).toEqual(DEFAULT_SETTINGS)
  })

  it('preserves unknown keys instead of dropping them', () => {
    // 다른 버전이 쓴 설정을 이 버전이 저장하면서 조용히 지우면 안 된다 — 원문 보존.
    expect(parseSettings('{"quickCaptureShortcut":"Alt+J","somethingElse":true}')).toEqual({
      ...DEFAULT_SETTINGS,
      quickCaptureShortcut: 'Alt+J',
      extra: { somethingElse: true },
    })
  })

  it('reads the suppressed-notice flag', () => {
    expect(parseSettings('{"suppressShortcutNotice":true}').suppressShortcutNotice).toBe(true)
    expect(parseSettings('{"suppressShortcutNotice":"yes"}').suppressShortcutNotice).toBe(false)
  })
})

describe('withQuickCaptureShortcut', () => {
  it('stores a normalized accelerator', () => {
    expect(withQuickCaptureShortcut(DEFAULT_SETTINGS, 'option+space')).toEqual({
      ...DEFAULT_SETTINGS,
      quickCaptureShortcut: 'Alt+Space',
    })
  })

  it('clears the override when given null', () => {
    expect(
      withQuickCaptureShortcut({ ...DEFAULT_SETTINGS, quickCaptureShortcut: 'Alt+J' }, null)
    ).toEqual(DEFAULT_SETTINGS)
  })

  it('carries unknown keys through untouched', () => {
    const stored = parseSettings('{"quickCaptureShortcut":"Alt+J","futureKey":{"a":1}}')
    expect(withQuickCaptureShortcut(stored, 'Alt+K').extra).toEqual({ futureKey: { a: 1 } })
  })

  it('refuses an invalid accelerator rather than storing garbage', () => {
    expect(() => withQuickCaptureShortcut(DEFAULT_SETTINGS, 'Space')).toThrow()
  })

  it('does not mutate the input', () => {
    const original = { ...DEFAULT_SETTINGS, quickCaptureShortcut: 'Alt+J' }
    withQuickCaptureShortcut(original, 'Alt+K')
    expect(original.quickCaptureShortcut).toBe('Alt+J')
  })
})

describe('withShortcutNoticeSuppressed', () => {
  it('records that the user asked not to see the warning again', () => {
    expect(withShortcutNoticeSuppressed(DEFAULT_SETTINGS, true).suppressShortcutNotice).toBe(true)
  })

  it('does not mutate the input', () => {
    const original = { ...DEFAULT_SETTINGS }
    withShortcutNoticeSuppressed(original, true)
    expect(original.suppressShortcutNotice).toBe(false)
  })
})

describe('serializeSettings', () => {
  it('round-trips through parseSettings', () => {
    const settings = withQuickCaptureShortcut(DEFAULT_SETTINGS, 'cmd+shift+k')
    expect(parseSettings(serializeSettings(settings))).toEqual(settings)
  })

  it('writes readable JSON', () => {
    expect(
      serializeSettings({ ...DEFAULT_SETTINGS, quickCaptureShortcut: 'Alt+Space' })
    ).toContain('\n')
  })

  it('round-trips unknown keys written by another version', () => {
    const stored = parseSettings('{"quickCaptureShortcut":"Alt+J","futureKey":{"a":1}}')
    expect(JSON.parse(serializeSettings(stored)).futureKey).toEqual({ a: 1 })
    expect(parseSettings(serializeSettings(stored))).toEqual(stored)
  })

  it('never lets an unknown key overwrite a known one', () => {
    const stored = parseSettings('{"quickCaptureShortcut":"Alt+J"}')
    expect(JSON.parse(serializeSettings(stored)).quickCaptureShortcut).toBe('Alt+J')
  })
})
