import { describe, expect, it, vi } from 'vitest'
import {
  describeShortcutState,
  handleShortcutSettingsEscape,
  isDefaultShortcut,
} from '../shortcut-settings'

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

function keyEvent(key: string) {
  return {
    key,
    preventDefault: vi.fn(),
    stopPropagation: vi.fn(),
  }
}

// Esc 한 겹 (BRU-126). 이 다이얼로그가 이미 받은 Esc가 피드 전역 핸들러까지
// 내려가면 포커스까지 같이 풀린다. 호출부가 preventDefault·stopPropagation을
// 빠뜨리지 못하게, 소비 계약은 여기 순수 함수에 둔다.
describe('handleShortcutSettingsEscape', () => {
  it('shouldConsumeEscapeSoTheFeedDoesNotAlsoClearFocus', () => {
    const event = keyEvent('Escape')
    expect(handleShortcutSettingsEscape(event, false)).toBe('close')
    expect(event.preventDefault).toHaveBeenCalledOnce()
    expect(event.stopPropagation).toHaveBeenCalledOnce()
  })

  // 녹음 중 Esc는 다이얼로그를 닫지 않는다 — 한 번에 한 겹 (BRU-109).
  it('shouldCancelRecordingBeforeClosingTheDialog', () => {
    const event = keyEvent('Escape')
    expect(handleShortcutSettingsEscape(event, true)).toBe('cancelRecording')
    expect(event.preventDefault).toHaveBeenCalledOnce()
    expect(event.stopPropagation).toHaveBeenCalledOnce()
  })

  it('shouldLeaveOtherKeysToTheCaller', () => {
    const event = keyEvent('j')
    expect(handleShortcutSettingsEscape(event, false)).toBeNull()
    expect(event.preventDefault).not.toHaveBeenCalled()
    expect(event.stopPropagation).not.toHaveBeenCalled()
  })
})
