// 노트 긴급도(priority)의 순환과 표기 규칙.
//
// 카드에서 긴급도는 맨 앞의 색 점 하나로 읽힌다 — 클릭하면 0 → 1 → 2 → 3 → 0으로 돈다.
// 색은 CSS 토큰(--priority-low/medium/high)에 매핑되므로 여기서는 클래스 이름만 정한다.

/** 긴급도 단계 수 (0 = 없음 … 3 = 최상) */
export const PRIORITY_LEVELS = 4

const PRIORITY_CLASS_NAMES = ['priority-none', 'priority-low', 'priority-medium', 'priority-high']

/** 다음 긴급도 — 마지막 단계에서는 처음으로 돌아온다 */
export function nextPriority(priority: number): number {
  return (priority + 1) % PRIORITY_LEVELS
}

/** 긴급도 점에 붙일 클래스 이름 — 알 수 없는 값은 중립으로 본다 */
export function priorityClassName(priority: number): string {
  return PRIORITY_CLASS_NAMES[priority] ?? PRIORITY_CLASS_NAMES[0]
}
