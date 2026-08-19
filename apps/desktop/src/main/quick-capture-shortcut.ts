/**
 * 전역 퀵캡처 단축키 등록 배선 (BRU-84).
 *
 * Electron의 `globalShortcut`을 직접 부르지 않고 주입받는다 — 배선 자체를 vitest로 덮기 위해서다.
 * 순수 규칙(정규화·시도 순서)은 `shared/shortcuts.ts`에 있고, 여기는 "실제로 잡혔는가"만 다룬다.
 */
import { buildRegistrationPlan } from '../shared/shortcuts'

/** Electron `globalShortcut`에서 이 모듈이 쓰는 부분만 추린 것. */
export interface GlobalShortcutRegistrar {
  register(accelerator: string, callback: () => void): boolean
  unregister(accelerator: string): void
}

export interface ShortcutRegistrationResult {
  /** 조합이 하나라도 잡혔는지 (기본값 폴백 포함). */
  ok: boolean
  /** 실제로 등록된 조합. 모두 실패하면 null. */
  accelerator: string | null
  /** 시도한 조합 전부 — 실패를 알릴 때 그대로 보여 준다. */
  attempted: string[]
}

export interface RegisterQuickCaptureShortcutOptions {
  registrar: GlobalShortcutRegistrar
  /** 사용자가 원한 조합(없으면 기본값). */
  preferred: string
  /** preferred가 실패했을 때 물러설 빌드 기본값. */
  fallback: string
  /** 지금 잡혀 있는 조합 — 새로 잡기 전에 놓아 준다. */
  previous?: string | null
  onTrigger: () => void
  /** 등록 시도가 던졌을 때 알림용 훅 (로그). */
  onError?: (accelerator: string, error: unknown) => void
}

/**
 * 사용자 지정 조합 → 빌드 기본값 순으로 등록을 시도한다.
 * 모두 실패하면 결과에 그대로 담아 호출자가 사용자에게 알릴 수 있게 한다 — 조용히 삼키지 않는다.
 */
export function registerQuickCaptureShortcut(
  options: RegisterQuickCaptureShortcutOptions
): ShortcutRegistrationResult {
  const { registrar, preferred, fallback, previous, onTrigger, onError } = options

  if (previous) registrar.unregister(previous)

  const attempted = buildRegistrationPlan(preferred, fallback)

  for (const accelerator of attempted) {
    let registered = false
    try {
      registered = registrar.register(accelerator, onTrigger)
    } catch (error) {
      // Electron은 표기를 못 읽으면 던진다 — 다음 후보로 넘어간다.
      onError?.(accelerator, error)
    }

    if (registered) {
      return { ok: true, accelerator, attempted }
    }
  }

  return { ok: false, accelerator: null, attempted }
}
