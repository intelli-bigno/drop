import { describe, expect, it, vi } from 'vitest'
import {
  type GlobalShortcutRegistrar,
  registerQuickCaptureShortcut,
} from './quick-capture-shortcut'

/** 지정한 조합만 등록에 성공하는 가짜 registrar. */
function fakeRegistrar(available: string[]): GlobalShortcutRegistrar & {
  registered: string[]
  unregistered: string[]
  callbacks: Map<string, () => void>
} {
  const registered: string[] = []
  const unregistered: string[] = []
  const callbacks = new Map<string, () => void>()

  return {
    registered,
    unregistered,
    callbacks,
    register(accelerator: string, callback: () => void): boolean {
      if (!available.includes(accelerator)) return false
      registered.push(accelerator)
      callbacks.set(accelerator, callback)
      return true
    },
    unregister(accelerator: string): void {
      unregistered.push(accelerator)
    },
  }
}

describe('registerQuickCaptureShortcut', () => {
  it('registers the preferred accelerator when it is free', () => {
    const registrar = fakeRegistrar(['Command+Shift+K', 'Alt+Space'])

    const result = registerQuickCaptureShortcut({
      registrar,
      preferred: 'Command+Shift+K',
      fallback: 'Alt+Space',
      onTrigger: () => {},
    })

    expect(result.ok).toBe(true)
    expect(result.accelerator).toBe('Command+Shift+K')
    expect(registrar.registered).toEqual(['Command+Shift+K'])
  })

  it('falls back to the default when the preferred accelerator is taken', () => {
    const registrar = fakeRegistrar(['Alt+Space'])

    const result = registerQuickCaptureShortcut({
      registrar,
      preferred: 'Command+Shift+K',
      fallback: 'Alt+Space',
      onTrigger: () => {},
    })

    expect(result.ok).toBe(true)
    expect(result.accelerator).toBe('Alt+Space')
    expect(result.attempted).toEqual(['Command+Shift+K', 'Alt+Space'])
  })

  it('reports failure with everything it tried when nothing is free', () => {
    const registrar = fakeRegistrar([])

    const result = registerQuickCaptureShortcut({
      registrar,
      preferred: 'Command+Shift+K',
      fallback: 'Alt+Space',
      onTrigger: () => {},
    })

    expect(result.ok).toBe(false)
    expect(result.accelerator).toBeNull()
    expect(result.attempted).toEqual(['Command+Shift+K', 'Alt+Space'])
  })

  it('releases the previously held accelerator before registering a new one', () => {
    const registrar = fakeRegistrar(['Alt+J'])

    registerQuickCaptureShortcut({
      registrar,
      preferred: 'Alt+J',
      fallback: 'Alt+Space',
      previous: 'Alt+Space',
      onTrigger: () => {},
    })

    expect(registrar.unregistered).toEqual(['Alt+Space'])
  })

  it('tries the default only once when it is also the preferred accelerator', () => {
    const registrar = fakeRegistrar([])

    const result = registerQuickCaptureShortcut({
      registrar,
      preferred: 'Alt+Space',
      fallback: 'Alt+Space',
      onTrigger: () => {},
    })

    expect(result.attempted).toEqual(['Alt+Space'])
  })

  it('keeps going when Electron throws on an accelerator it cannot parse', () => {
    const registrar = fakeRegistrar(['Alt+Space'])
    const onError = vi.fn()
    const exploding: GlobalShortcutRegistrar = {
      register(accelerator, callback) {
        if (accelerator === 'Command+Shift+K') throw new Error('boom')
        return registrar.register(accelerator, callback)
      },
      unregister: registrar.unregister,
    }

    const result = registerQuickCaptureShortcut({
      registrar: exploding,
      preferred: 'Command+Shift+K',
      fallback: 'Alt+Space',
      onTrigger: () => {},
      onError,
    })

    expect(result.ok).toBe(true)
    expect(result.accelerator).toBe('Alt+Space')
    expect(onError).toHaveBeenCalledWith('Command+Shift+K', expect.any(Error))
  })

  it('wires the trigger callback to the accelerator that was registered', () => {
    const registrar = fakeRegistrar(['Alt+Space'])
    const onTrigger = vi.fn()

    registerQuickCaptureShortcut({
      registrar,
      preferred: 'Alt+Space',
      fallback: 'Alt+Space',
      onTrigger,
    })

    registrar.callbacks.get('Alt+Space')?.()
    expect(onTrigger).toHaveBeenCalledTimes(1)
  })
})
