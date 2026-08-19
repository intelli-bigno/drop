import { describe, expect, it } from 'vitest'
import { DEFAULT_SETTINGS, parseSettings, serializeSettings, withQuickCaptureShortcut } from './settings'

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
      quickCaptureShortcut: 'Command+Shift+K',
    })
  })

  it('drops a stored shortcut that is no longer valid', () => {
    expect(parseSettings('{"quickCaptureShortcut":"Space"}')).toEqual(DEFAULT_SETTINGS)
    expect(parseSettings('{"quickCaptureShortcut":42}')).toEqual(DEFAULT_SETTINGS)
  })

  it('ignores unknown keys', () => {
    expect(parseSettings('{"quickCaptureShortcut":"Alt+J","somethingElse":true}')).toEqual({
      quickCaptureShortcut: 'Alt+J',
    })
  })
})

describe('withQuickCaptureShortcut', () => {
  it('stores a normalized accelerator', () => {
    expect(withQuickCaptureShortcut(DEFAULT_SETTINGS, 'option+space')).toEqual({
      quickCaptureShortcut: 'Alt+Space',
    })
  })

  it('clears the override when given null', () => {
    expect(withQuickCaptureShortcut({ quickCaptureShortcut: 'Alt+J' }, null)).toEqual(
      DEFAULT_SETTINGS
    )
  })

  it('refuses an invalid accelerator rather than storing garbage', () => {
    expect(() => withQuickCaptureShortcut(DEFAULT_SETTINGS, 'Space')).toThrow()
  })

  it('does not mutate the input', () => {
    const original = { quickCaptureShortcut: 'Alt+J' }
    withQuickCaptureShortcut(original, 'Alt+K')
    expect(original).toEqual({ quickCaptureShortcut: 'Alt+J' })
  })
})

describe('serializeSettings', () => {
  it('round-trips through parseSettings', () => {
    const settings = withQuickCaptureShortcut(DEFAULT_SETTINGS, 'cmd+shift+k')
    expect(parseSettings(serializeSettings(settings))).toEqual(settings)
  })

  it('writes readable JSON', () => {
    expect(serializeSettings({ quickCaptureShortcut: 'Alt+Space' })).toContain('\n')
  })
})
