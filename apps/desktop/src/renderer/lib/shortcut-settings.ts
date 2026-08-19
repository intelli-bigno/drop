import { formatAccelerator } from '../../shared/shortcuts'

/** preload가 넘겨주는 단축키 상태 (BRU-84). */
export interface QuickCaptureShortcutState {
  accelerator: string | null
  custom: string | null
  fallback: string
  registered: boolean
}

export interface ShortcutStatus {
  tone: 'ok' | 'error'
  text: string
}

/** 화면에 그대로 보여 줄 한 줄. 등록 실패는 반드시 눈에 보여야 한다. */
export function describeShortcutState(
  state: QuickCaptureShortcutState,
  platform: string = 'darwin'
): ShortcutStatus {
  if (!state.registered || !state.accelerator) {
    const attempted = state.custom ?? state.fallback
    return {
      tone: 'error',
      text: `${formatAccelerator(attempted, platform)} 조합을 등록하지 못했습니다 — 다른 앱이 쓰고 있습니다. 다른 조합을 골라 주세요.`,
    }
  }

  // 고른 조합이 아니라 기본값이 잡혀 있으면 그건 성공이 아니다.
  if (state.custom !== null && state.custom !== state.accelerator) {
    return {
      tone: 'error',
      text:
        `${formatAccelerator(state.custom, platform)} 조합을 등록하지 못했습니다 — 다른 앱이 쓰고 있습니다. ` +
        `지금은 기본값 ${formatAccelerator(state.accelerator, platform)} 로 열립니다.`,
    }
  }

  const rendered = formatAccelerator(state.accelerator, platform)
  return {
    tone: 'ok',
    text: isDefaultShortcut(state)
      ? `${rendered} 로 어디서든 퀵캡처가 열립니다 (기본값).`
      : `${rendered} 로 어디서든 퀵캡처가 열립니다.`,
  }
}

/** 사용자가 직접 고른 조합이 없으면 기본값을 쓰고 있는 것이다. */
export function isDefaultShortcut(state: QuickCaptureShortcutState): boolean {
  return state.custom === null
}
