/**
 * Ctrl 더블 탭 전역 후킹 배선 (BRU-103).
 *
 * uiohook을 직접 부르지 않고 주입받는다 — 네이티브 모듈 없이 vitest로 덮기 위해서다.
 * 판정 규칙은 `shared/double-ctrl.ts`에 있고, 여기는 "후킹이 실제로 붙었는가"만 다룬다.
 */
import { createDoubleCtrlDetector, type DoubleCtrlDetector } from '../shared/double-ctrl'

export interface KeyHookEvent {
  keycode: number
}

/** uiohook-napi `uIOhook`에서 이 모듈이 쓰는 부분만 추린 것. */
export interface GlobalKeyHook {
  on(event: 'keydown' | 'keyup', listener: (e: KeyHookEvent) => void): void
  start(): void
  stop(): void
}

export interface AttachDoubleCtrlCaptureOptions {
  hook: GlobalKeyHook
  /** Ctrl로 취급할 키코드 — 왼쪽·오른쪽 둘 다 넘긴다. */
  ctrlKeycodes: readonly number[]
  onTrigger: () => void
  now?: () => number
  detector?: DoubleCtrlDetector
}

export interface DoubleCtrlAttachResult {
  /** 후킹이 실제로 붙었는지. */
  ok: boolean
  /** start()가 던진 오류 — 사용자에게 알릴 때 그대로 쓴다. */
  error?: unknown
  dispose(): void
}

export function attachDoubleCtrlCapture(
  options: AttachDoubleCtrlCaptureOptions
): DoubleCtrlAttachResult {
  const { hook, onTrigger } = options
  const now = options.now ?? Date.now
  const detector = options.detector ?? createDoubleCtrlDetector()
  const ctrlKeycodes = new Set(options.ctrlKeycodes)

  let disposed = false

  function feed(type: 'down' | 'up', event: KeyHookEvent): void {
    if (disposed) return
    const fired = detector.handle({
      isCtrl: ctrlKeycodes.has(event.keycode),
      type,
      timeMs: now(),
    })
    if (fired) onTrigger()
  }

  hook.on('keydown', (event) => feed('down', event))
  hook.on('keyup', (event) => feed('up', event))

  function dispose(): void {
    if (disposed) return
    disposed = true
    try {
      hook.stop()
    } catch {
      // 이미 죽은 후킹을 멈추다 실패한 것은 알릴 일이 없다.
    }
  }

  try {
    hook.start()
  } catch (error) {
    disposed = true
    return { ok: false, error, dispose }
  }

  return { ok: true, dispose }
}
