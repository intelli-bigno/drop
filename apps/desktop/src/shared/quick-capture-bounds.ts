/**
 * 퀵캡처 창 높이 (BRU-116).
 *
 * 렌더러가 ResizeObserver로 잰 카드 높이에 바깥 패딩을 더하고 cap에서 자른다.
 * 잘린 나머지는 카드 안에서 스크롤한다.
 *
 * 위치 정책은 **top-stable**: 높이가 바뀌어도 위 가장자리(y)는 그대로 둔다.
 * `center: true`로 다시 맞추면 창이 위아래로 튄다.
 *
 * Electron을 부르지 않는 순수 모듈이라 main·테스트가 같은 규칙을 쓴다.
 */

export const QUICK_CAPTURE_WINDOW_WIDTH = 600
/** 빈 카드(첨부 없음) 기준 초기 높이. 이보다 작아지지 않는다. */
export const QUICK_CAPTURE_WINDOW_MIN_HEIGHT = 80
/** 첨부 많은 창이 화면을 덮지 않게. 넘으면 카드 overflow-y: auto. */
export const QUICK_CAPTURE_WINDOW_MAX_HEIGHT = 400
/** `.quick-capture` padding — `--space-2` = 8px. 상하 합치면 16. */
export const QUICK_CAPTURE_WINDOW_PADDING = 8

export interface QuickCaptureBounds {
  x: number
  y: number
  width: number
  height: number
}

/**
 * cardHeight + padding×2 를 cap에서 자른 창 높이.
 * padding은 한쪽(상 또는 하) 값이다.
 */
export function calculateQuickCaptureWindowHeight(
  cardHeight: number,
  padding: number,
  cap: number
): number {
  const raw = Math.ceil(cardHeight + padding * 2)
  if (raw <= QUICK_CAPTURE_WINDOW_MIN_HEIGHT) return QUICK_CAPTURE_WINDOW_MIN_HEIGHT
  if (raw >= cap) return cap
  return raw
}

/**
 * 다음 창 바운드. 높이가 안 바뀌면 null — 호출부가 setBounds를 건너뛴다.
 * width·x·y는 현재 값을 유지한다 (top-stable).
 */
export function nextQuickCaptureBounds(
  current: QuickCaptureBounds,
  cardHeight: number,
  padding: number = QUICK_CAPTURE_WINDOW_PADDING,
  cap: number = QUICK_CAPTURE_WINDOW_MAX_HEIGHT
): QuickCaptureBounds | null {
  const height = calculateQuickCaptureWindowHeight(cardHeight, padding, cap)
  if (height === current.height) return null
  return {
    x: current.x,
    y: current.y,
    width: current.width,
    height,
  }
}
