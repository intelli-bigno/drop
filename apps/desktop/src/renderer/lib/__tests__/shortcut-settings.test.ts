import { describe, expect, it } from 'vitest'
import { describeShortcutState, isDefaultShortcut } from '../shortcut-settings'

const registered = {
  accelerator: 'Alt+Space',
  custom: null,
  fallback: 'Alt+Space',
  registered: true,
}

describe('describeShortcutState', () => {
  it('reports the registered combination', () => {
    const status = describeShortcutState(registered, 'darwin')
    expect(status.tone).toBe('ok')
    expect(status.text).toContain('⌥Space')
  })

  it('says so when the shortcut could not be registered — the failure must be visible', () => {
    const status = describeShortcutState(
      { accelerator: null, custom: 'Command+Shift+K', fallback: 'Alt+Space', registered: false },
      'darwin'
    )
    expect(status.tone).toBe('error')
    expect(status.text).toContain('등록')
  })

  it('marks a user-chosen combination as customized', () => {
    const status = describeShortcutState(
      { accelerator: 'Command+Shift+K', custom: 'Command+Shift+K', fallback: 'Alt+Space', registered: true },
      'darwin'
    )
    expect(status.tone).toBe('ok')
    expect(status.text).toContain('⇧⌘K')
  })

  it('flags the case where a custom combination silently fell back to the default', () => {
    const status = describeShortcutState(
      {
        accelerator: 'Alt+Space',
        custom: 'Command+Shift+K',
        fallback: 'Alt+Space',
        registered: true,
      },
      'darwin'
    )
    expect(status.tone).toBe('error')
    expect(status.text).toContain('⇧⌘K')
    expect(status.text).toContain('⌥Space')
  })

  it('renders word modifiers off macOS', () => {
    expect(describeShortcutState(registered, 'win32').text).toContain('Alt+Space')
  })
})

describe('isDefaultShortcut', () => {
  it('is true while no custom combination is stored', () => {
    expect(isDefaultShortcut(registered)).toBe(true)
  })

  it('is false once the user picked their own', () => {
    expect(isDefaultShortcut({ ...registered, custom: 'Command+Shift+K' })).toBe(false)
  })
})
