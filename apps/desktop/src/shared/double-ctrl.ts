/**
 * Ctrl 더블 탭 감지 (BRU-103).
 *
 * Electron accelerator는 수식키 단독·연타를 표현하지 못하므로 전역 키 이벤트를 직접 읽어
 * 판정한다. 이 모듈은 판정 규칙만 담은 순수 상태 기계다 — 키 후킹(uiohook)은 main에서 주입한다.
 *
 * 발화 시점은 **두 번째 Ctrl 누름**이다 (JetBrains 더블 Ctrl과 같은 방식).
 * macOS에서 수식키는 flagsChanged 기반이라 자동 반복이 없어, 누름 두 번은 곧 탭 두 번이다.
 * 뗌(keyup) 시점 발화는 합성 이벤트(cliclick 등)에서 수식키 keyup이 유실되면 영구히
 * 침묵하는 것을 실측으로 확인해 버렸다 — 누름 기반은 keyup이 없어도 동작한다.
 *
 * 트레이드오프: "깨끗한 탭 직후 400ms 안에 Ctrl 조합을 시작"하면 오발화한다.
 * Ctrl 단독 탭은 평소 아무 일도 하지 않으므로 실사용에서 이 시퀀스는 드물다고 판단했다.
 */
import { formatAccelerator } from './shortcuts'

export interface DoubleCtrlKeyEvent {
  /** 이 이벤트가 Ctrl(왼쪽·오른쪽 불문)인지. 매핑은 호출자 책임. */
  isCtrl: boolean
  type: 'down' | 'up'
  timeMs: number
}

export interface DoubleCtrlDetectorOptions {
  /** 누름→뗌이 이보다 길면 탭이 아니라 홀드다 (keyup이 왔을 때만 판정 가능). */
  maxTapMs?: number
  /** 첫 탭 이후 두 번째 누름까지 허용하는 추가 간격. */
  maxGapMs?: number
}

export const DEFAULT_MAX_TAP_MS = 350
export const DEFAULT_MAX_GAP_MS = 400

export interface DoubleCtrlDetector {
  /** 이벤트 하나를 반영하고, 이 이벤트로 더블 탭이 완성됐는지 돌려준다. */
  handle(event: DoubleCtrlKeyEvent): boolean
  reset(): void
}

export function createDoubleCtrlDetector(
  options: DoubleCtrlDetectorOptions = {}
): DoubleCtrlDetector {
  const maxTapMs = options.maxTapMs ?? DEFAULT_MAX_TAP_MS
  const maxGapMs = options.maxGapMs ?? DEFAULT_MAX_GAP_MS
  /** 첫 누름 → 두 번째 누름 허용 창. keyup 유실에 대비해 누름끼리 비교한다. */
  const chainWindowMs = maxTapMs + maxGapMs

  /** 첫 탭 후보의 누름 시각. 없으면 null. */
  let candidateDownAt: number | null = null

  function reset(): void {
    candidateDownAt = null
  }

  function handle(event: DoubleCtrlKeyEvent): boolean {
    if (!event.isCtrl) {
      // Ctrl이 눌린 채면 조합 사용이고, 아니면 탭 사이에 낀 입력이다 — 둘 다 후보를 지운다.
      if (event.type === 'down') candidateDownAt = null
      return false
    }

    if (event.type === 'up') {
      // 오래 눌렀다 뗐으면 탭이 아니라 홀드였다 — 후보 취소.
      if (candidateDownAt !== null && event.timeMs - candidateDownAt > maxTapMs) {
        candidateDownAt = null
      }
      return false
    }

    // ctrl keydown
    if (candidateDownAt !== null && event.timeMs - candidateDownAt <= chainWindowMs) {
      candidateDownAt = null
      return true
    }

    candidateDownAt = event.timeMs
    return false
  }

  return { handle, reset }
}

/** 사람이 읽는 표기 — 트레이·알림에서 쓴다. */
export const DOUBLE_CTRL_DISPLAY = '⌃ 두 번'

/**
 * Ctrl 더블 탭을 기본 호출 경로로 쓸지.
 *
 * 사용자가 조합을 직접 골랐으면 그걸 존중하고, macOS 밖은 후킹을 검증하지 않았으므로
 * 기존 accelerator 경로를 유지한다. dev 실행은 설치본과 같은 키를 두 인스턴스가
 * 동시에 받게 되므로 명시적 opt-in(`DROP_DEV_DOUBLE_CTRL=1`) 없이는 쓰지 않는다.
 */
export function shouldUseDoubleCtrlCapture(options: {
  storedAccelerator: string | null
  isPackaged: boolean
  platform: string
  devOptIn?: boolean
}): boolean {
  if (options.storedAccelerator) return false
  if (options.platform !== 'darwin') return false
  if (!options.isPackaged && !options.devOptIn) return false
  return true
}

/**
 * 손쉬운 사용 권한이 없어 accelerator로 물러섰을 때의 문구.
 * BRU-84의 원칙 그대로 — 조용히 삼키지 않는다.
 */
export function describeDoubleCtrlPermissionFallback(
  fallbackAccelerator: string,
  platform: string = 'darwin'
): { title: string; message: string } {
  const fallback = formatAccelerator(fallbackAccelerator, platform)

  return {
    title: 'Ctrl 두 번 호출에 권한이 필요합니다',
    message:
      `퀵캡처를 ${DOUBLE_CTRL_DISPLAY}으로 열려면 손쉬운 사용 권한이 필요합니다.\n` +
      '시스템 설정 → 개인정보 보호 및 보안 → 손쉬운 사용에서 DROP을 허용한 뒤 앱을 다시 실행하세요.\n\n' +
      `지금은 ${fallback} 로 퀵캡처가 열립니다.`,
  }
}

/** 권한은 있는데 키 후킹 시작 자체가 실패했을 때의 문구. */
export function describeDoubleCtrlStartFailure(
  fallbackAccelerator: string,
  platform: string = 'darwin'
): { title: string; message: string } {
  const fallback = formatAccelerator(fallbackAccelerator, platform)

  return {
    title: 'Ctrl 두 번 호출을 켜지 못했습니다',
    message:
      `전역 키 감지를 시작하지 못해 ${DOUBLE_CTRL_DISPLAY} 호출이 꺼졌습니다.\n` +
      `지금은 ${fallback} 로 퀵캡처가 열립니다. 앱을 다시 실행하면 다시 시도합니다.`,
  }
}
