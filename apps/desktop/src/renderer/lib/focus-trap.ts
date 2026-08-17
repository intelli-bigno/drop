/**
 * 모달 다이얼로그 포커스 트랩의 순수 로직.
 * DOM 접근은 호출자(컴포넌트)가 하고, 여기서는 "다음에 몇 번째로 가야 하는가"만 결정한다.
 */

/** Tab 순환에 포함될 요소들의 선택자 — disabled·tabindex="-1"은 제외한다. */
export const FOCUSABLE_SELECTOR = [
  'button:not([disabled])',
  'a[href]',
  'input:not([disabled])',
  'select:not([disabled])',
  'textarea:not([disabled])',
  '[tabindex]:not([tabindex="-1"])',
].join(', ')

interface NextFocusInput {
  /** 다이얼로그 안에서 포커스 가능한 요소 수 */
  count: number
  /** 현재 포커스된 요소의 인덱스. 다이얼로그 밖이면 -1 */
  currentIndex: number
  shiftKey: boolean
}

/**
 * Tab / Shift+Tab이 눌렸을 때 포커스를 옮길 인덱스.
 * 끝에서 반대쪽 끝으로 감싸므로 포커스가 다이얼로그를 벗어나지 않는다.
 * 포커스 가능한 요소가 없으면 -1(이동 대상 없음).
 */
export function nextFocusIndex({ count, currentIndex, shiftKey }: NextFocusInput): number {
  if (count <= 0) return -1
  // 포커스가 이미 밖으로 새어 나갔으면 양 끝에서 다시 잡는다
  if (currentIndex < 0) return shiftKey ? count - 1 : 0
  return (currentIndex + (shiftKey ? -1 : 1) + count) % count
}
