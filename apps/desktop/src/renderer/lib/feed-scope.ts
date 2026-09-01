// 피드 범위 필터 — Inbox와 할일을 한 축으로 합친 것 (BRU-199).
//
// 원래는 버튼이 둘이었다(InboxFilter 2상태 토글 + TodoFilter 3상태 순환).
// BRU-181에서 "할일로 분류된 노트는 Inbox를 떠난다"로 Inbox 정의를 타입 축과
// 정렬시킨 뒤로 두 축은 사실상 배타가 됐다 — 배타인 값들은 버튼 둘보다
// 순환 하나가 맞다. 긴급도 점이 이미 같은 방식으로 돈다.
//
// null은 "이 축으로 걸러내지 않음"이다. 'inbox'는 아직 분류되지 않은 노트,
// 'todo'는 할일 전부(끝난 것 포함), 'open'은 아직 안 끝난 할일만.

export type FeedScope = 'inbox' | 'todo' | 'open' | null

/**
 * 버튼을 누를 때 도는 순서. **여기가 순환의 단일 출처다** —
 * 컴포넌트가 삼항으로 다음 값을 계산하면 상태가 하나 늘 때마다 조용히 빠진다.
 */
export const FEED_SCOPE_CYCLE: readonly FeedScope[] = [null, 'inbox', 'todo', 'open']

export function nextFeedScope(scope: FeedScope): FeedScope {
  const index = FEED_SCOPE_CYCLE.indexOf(scope)
  // 모르는 값이 들어오면 처음으로 돌린다 — 눌러도 아무 일이 없는 것보다 낫다
  if (index === -1) return FEED_SCOPE_CYCLE[0]
  return FEED_SCOPE_CYCLE[(index + 1) % FEED_SCOPE_CYCLE.length]
}
