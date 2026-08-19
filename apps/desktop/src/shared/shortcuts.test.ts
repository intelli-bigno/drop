import { describe, expect, it } from 'vitest'
import {
  DEFAULT_QUICK_CAPTURE_ACCELERATOR,
  DEV_QUICK_CAPTURE_ACCELERATOR,
  acceleratorFromKeyEvent,
  buildRegistrationPlan,
  describeFallbackRegistration,
  describeRegistrationFailure,
  formatAccelerator,
  isValidAccelerator,
  normalizeAccelerator,
  resolveQuickCaptureAccelerator,
  shouldReturnFocusToPreviousApp,
} from './shortcuts'

describe('DEFAULT_QUICK_CAPTURE_ACCELERATOR', () => {
  it('is Option+Space — the combination decided in BRU-84', () => {
    expect(DEFAULT_QUICK_CAPTURE_ACCELERATOR).toBe('Alt+Space')
  })

  it('uses a different combination in development so it cannot fight the installed build', () => {
    expect(DEV_QUICK_CAPTURE_ACCELERATOR).not.toBe(DEFAULT_QUICK_CAPTURE_ACCELERATOR)
    expect(isValidAccelerator(DEV_QUICK_CAPTURE_ACCELERATOR)).toBe(true)
  })
})

describe('normalizeAccelerator', () => {
  it('canonicalizes modifier aliases', () => {
    expect(normalizeAccelerator('option+space')).toBe('Alt+Space')
    expect(normalizeAccelerator('opt+Space')).toBe('Alt+Space')
    expect(normalizeAccelerator('cmd+shift+n')).toBe('Command+Shift+N')
    expect(normalizeAccelerator('meta+K')).toBe('Command+K')
    expect(normalizeAccelerator('ctrl+space')).toBe('Control+Space')
  })

  it('puts modifiers in a stable order regardless of input order', () => {
    expect(normalizeAccelerator('Shift+Alt+Control+Command+N')).toBe(
      'Command+Control+Alt+Shift+N'
    )
    expect(normalizeAccelerator('Command+Control+Alt+Shift+N')).toBe(
      'Command+Control+Alt+Shift+N'
    )
  })

  it('tolerates surrounding whitespace', () => {
    expect(normalizeAccelerator('  alt +  space ')).toBe('Alt+Space')
  })

  it('uppercases single letters and keeps function keys', () => {
    expect(normalizeAccelerator('alt+j')).toBe('Alt+J')
    expect(normalizeAccelerator('alt+f12')).toBe('Alt+F12')
    expect(normalizeAccelerator('alt+1')).toBe('Alt+1')
  })

  it('accepts named keys', () => {
    expect(normalizeAccelerator('alt+enter')).toBe('Alt+Return')
    expect(normalizeAccelerator('alt+up')).toBe('Alt+Up')
    expect(normalizeAccelerator('alt+pageup')).toBe('Alt+PageUp')
  })

  it('rejects a combination without any modifier — it would swallow the key everywhere', () => {
    expect(normalizeAccelerator('Space')).toBeNull()
    expect(normalizeAccelerator('J')).toBeNull()
  })

  it('rejects a combination without a key', () => {
    expect(normalizeAccelerator('Alt+Shift')).toBeNull()
    expect(normalizeAccelerator('')).toBeNull()
  })

  it('rejects more than one non-modifier key', () => {
    expect(normalizeAccelerator('Alt+Space+J')).toBeNull()
  })

  it('rejects Escape — a global Escape hijacks every app', () => {
    expect(normalizeAccelerator('Alt+Escape')).toBeNull()
  })

  it('rejects unknown keys', () => {
    expect(normalizeAccelerator('Alt+Banana')).toBeNull()
  })
})

describe('isValidAccelerator', () => {
  it('mirrors normalizeAccelerator', () => {
    expect(isValidAccelerator('Alt+Space')).toBe(true)
    expect(isValidAccelerator('Space')).toBe(false)
  })
})

describe('formatAccelerator', () => {
  it('renders macOS glyphs in the conventional order', () => {
    expect(formatAccelerator('Alt+Space', 'darwin')).toBe('⌥Space')
    expect(formatAccelerator('Command+Control+Alt+Shift+N', 'darwin')).toBe('⌃⌥⇧⌘N')
  })

  it('renders word modifiers elsewhere', () => {
    expect(formatAccelerator('Alt+Space', 'win32')).toBe('Alt+Space')
    expect(formatAccelerator('Command+Shift+N', 'win32')).toBe('Super+Shift+N')
  })

  it('normalizes before rendering', () => {
    expect(formatAccelerator('option+space', 'darwin')).toBe('⌥Space')
  })

  it('returns the raw string when it cannot be parsed', () => {
    expect(formatAccelerator('Banana', 'darwin')).toBe('Banana')
  })
})

describe('resolveQuickCaptureAccelerator', () => {
  it('uses the stored accelerator when it is valid', () => {
    expect(resolveQuickCaptureAccelerator({ stored: 'cmd+shift+k', isPackaged: true })).toBe(
      'Command+Shift+K'
    )
  })

  it('falls back to the packaged default when nothing is stored', () => {
    expect(resolveQuickCaptureAccelerator({ stored: null, isPackaged: true })).toBe(
      DEFAULT_QUICK_CAPTURE_ACCELERATOR
    )
  })

  it('falls back to the development default when running unpackaged', () => {
    expect(resolveQuickCaptureAccelerator({ stored: undefined, isPackaged: false })).toBe(
      DEV_QUICK_CAPTURE_ACCELERATOR
    )
  })

  it('ignores a stored value that is no longer valid', () => {
    expect(resolveQuickCaptureAccelerator({ stored: 'Space', isPackaged: true })).toBe(
      DEFAULT_QUICK_CAPTURE_ACCELERATOR
    )
  })
})

describe('buildRegistrationPlan', () => {
  it('tries the preferred accelerator, then the fallback', () => {
    expect(buildRegistrationPlan('Command+Shift+K', 'Alt+Space')).toEqual([
      'Command+Shift+K',
      'Alt+Space',
    ])
  })

  it('does not repeat the fallback when it equals the preferred one', () => {
    expect(buildRegistrationPlan('Alt+Space', 'Alt+Space')).toEqual(['Alt+Space'])
  })

  it('drops an invalid preferred accelerator', () => {
    expect(buildRegistrationPlan('Space', 'Alt+Space')).toEqual(['Alt+Space'])
  })
})

describe('describeRegistrationFailure', () => {
  it('names every accelerator that was tried so the failure is not silent', () => {
    const { title, message } = describeRegistrationFailure(['Command+Shift+K', 'Alt+Space'], 'darwin')
    expect(title).toContain('단축키')
    expect(message).toContain('⇧⌘K')
    expect(message).toContain('⌥Space')
  })

  it('tells the user where to change the combination', () => {
    const { message } = describeRegistrationFailure(['Alt+Space'], 'darwin')
    expect(message).toContain('설정')
  })
})

describe('shouldReturnFocusToPreviousApp', () => {
  it('returns focus when the capture was triggered from another app on macOS', () => {
    expect(shouldReturnFocusToPreviousApp({ platform: 'darwin', invokedFromOtherApp: true })).toBe(
      true
    )
  })

  it('does not hide the app when the capture was triggered from within the app', () => {
    expect(shouldReturnFocusToPreviousApp({ platform: 'darwin', invokedFromOtherApp: false })).toBe(
      false
    )
  })

  it('only applies to macOS — other platforms have no app-level hide', () => {
    expect(shouldReturnFocusToPreviousApp({ platform: 'win32', invokedFromOtherApp: true })).toBe(
      false
    )
  })
})

describe('acceleratorFromKeyEvent', () => {
  const base = { metaKey: false, ctrlKey: false, altKey: false, shiftKey: false }

  it('reads the physical key so Option-mangled characters do not leak in', () => {
    // macOS turns Option+Space into a non-breaking space in event.key
    expect(acceleratorFromKeyEvent({ ...base, altKey: true, key: ' ', code: 'Space' })).toBe(
      'Alt+Space'
    )
    // Option+A produces 'å'
    expect(acceleratorFromKeyEvent({ ...base, altKey: true, key: 'å', code: 'KeyA' })).toBe('Alt+A')
  })

  it('maps digits, function keys and arrows', () => {
    expect(acceleratorFromKeyEvent({ ...base, ctrlKey: true, key: '1', code: 'Digit1' })).toBe(
      'Control+1'
    )
    expect(acceleratorFromKeyEvent({ ...base, altKey: true, key: 'F5', code: 'F5' })).toBe('Alt+F5')
    expect(acceleratorFromKeyEvent({ ...base, altKey: true, key: 'ArrowUp', code: 'ArrowUp' })).toBe(
      'Alt+Up'
    )
  })

  it('combines modifiers in canonical order', () => {
    expect(
      acceleratorFromKeyEvent({
        key: 'K',
        code: 'KeyK',
        metaKey: true,
        ctrlKey: false,
        altKey: true,
        shiftKey: true,
      })
    ).toBe('Command+Alt+Shift+K')
  })

  it('returns null while only modifiers are held', () => {
    expect(acceleratorFromKeyEvent({ ...base, altKey: true, key: 'Alt', code: 'AltLeft' })).toBeNull()
    expect(
      acceleratorFromKeyEvent({ ...base, shiftKey: true, key: 'Shift', code: 'ShiftLeft' })
    ).toBeNull()
  })

  it('returns null for a bare key with no modifier', () => {
    expect(acceleratorFromKeyEvent({ ...base, key: 'a', code: 'KeyA' })).toBeNull()
  })

  it('returns null for Escape so the dialog can still be dismissed', () => {
    expect(
      acceleratorFromKeyEvent({ ...base, altKey: true, key: 'Escape', code: 'Escape' })
    ).toBeNull()
  })
})

describe('describeFallbackRegistration', () => {
  it('names both the combination that failed and the one actually in use', () => {
    const { message } = describeFallbackRegistration('Command+Shift+K', 'Alt+Space', 'darwin')
    expect(message).toContain('⇧⌘K')
    expect(message).toContain('⌥Space')
  })

  it('does not claim that nothing was registered', () => {
    const { message } = describeFallbackRegistration('Command+Shift+K', 'Alt+Space', 'darwin')
    expect(message).not.toContain('등록되지 않았습니다')
  })
})
