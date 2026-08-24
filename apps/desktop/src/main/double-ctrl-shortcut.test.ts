import { describe, expect, it, vi } from 'vitest'
import { attachDoubleCtrlCapture, type GlobalKeyHook, type KeyHookEvent } from './double-ctrl-shortcut'

const CTRL = 29
const CTRL_RIGHT = 3613
const KEY_C = 46

class FakeHook implements GlobalKeyHook {
  started = 0
  stopped = 0
  startError: Error | null = null
  private listeners: Record<string, Array<(e: KeyHookEvent) => void>> = {}

  on(event: 'keydown' | 'keyup', listener: (e: KeyHookEvent) => void): void {
    ;(this.listeners[event] ??= []).push(listener)
  }

  start(): void {
    if (this.startError) throw this.startError
    this.started += 1
  }

  stop(): void {
    this.stopped += 1
  }

  emit(event: 'keydown' | 'keyup', keycode: number): void {
    for (const listener of this.listeners[event] ?? []) listener({ keycode })
  }
}

function setup(overrides: { startError?: Error } = {}) {
  const hook = new FakeHook()
  if (overrides.startError) hook.startError = overrides.startError
  const onTrigger = vi.fn()
  let timeMs = 0
  const result = attachDoubleCtrlCapture({
    hook,
    ctrlKeycodes: [CTRL, CTRL_RIGHT],
    onTrigger,
    now: () => timeMs,
  })
  return { hook, onTrigger, result, advance: (to: number) => (timeMs = to) }
}

describe('attachDoubleCtrlCapture', () => {
  it('Ctrl 두 번 탭이면 트리거를 부른다', () => {
    const { hook, onTrigger, advance } = setup()
    hook.emit('keydown', CTRL)
    advance(80)
    hook.emit('keyup', CTRL)
    advance(200)
    hook.emit('keydown', CTRL)
    advance(280)
    hook.emit('keyup', CTRL)
    expect(onTrigger).toHaveBeenCalledTimes(1)
  })

  it('오른쪽 Ctrl도 같은 키로 취급한다', () => {
    const { hook, onTrigger, advance } = setup()
    hook.emit('keydown', CTRL_RIGHT)
    advance(80)
    hook.emit('keyup', CTRL_RIGHT)
    advance(200)
    hook.emit('keydown', CTRL)
    advance(280)
    hook.emit('keyup', CTRL)
    expect(onTrigger).toHaveBeenCalledTimes(1)
  })

  it('Ctrl+C 조합은 트리거하지 않는다', () => {
    const { hook, onTrigger, advance } = setup()
    hook.emit('keydown', CTRL)
    advance(50)
    hook.emit('keydown', KEY_C)
    hook.emit('keyup', KEY_C)
    advance(100)
    hook.emit('keyup', CTRL)
    advance(200)
    hook.emit('keydown', CTRL)
    advance(280)
    hook.emit('keyup', CTRL)
    expect(onTrigger).not.toHaveBeenCalled()
  })

  it('후킹 시작에 성공하면 ok, dispose가 stop을 부른다', () => {
    const { hook, result } = setup()
    expect(result.ok).toBe(true)
    expect(hook.started).toBe(1)
    result.dispose()
    expect(hook.stopped).toBe(1)
  })

  it('후킹 시작이 던지면 ok=false에 오류를 담아 돌려준다 — 조용히 삼키지 않는다', () => {
    const error = new Error('accessibility denied')
    const { result } = setup({ startError: error })
    expect(result.ok).toBe(false)
    expect(result.error).toBe(error)
  })

  it('dispose 이후 이벤트는 무시된다', () => {
    const { hook, onTrigger, result, advance } = setup()
    result.dispose()
    hook.emit('keydown', CTRL)
    advance(80)
    hook.emit('keyup', CTRL)
    advance(200)
    hook.emit('keydown', CTRL)
    advance(280)
    hook.emit('keyup', CTRL)
    expect(onTrigger).not.toHaveBeenCalled()
  })
})
