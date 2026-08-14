// 한 줄 카드의 오른쪽 끝 자리(BRU-46).
//
// 평소에는 상대 시간이 있고, 호버하거나 키보드 포커스를 받으면 같은 자리가
// 액션 버튼으로 바뀐다. 호버 전용으로 만들면 키보드만 쓰는 사람에게는
// 버튼이 없는 앱이 되므로 포커스도 같은 자격으로 본다.
//
// 자리 자체는 CSS가 겹쳐 그린다(액션은 시간 위에 absolute) — 그래야 버튼 수와
// 무관하게 줄 폭이 흔들리지 않는다.

export type TrailingSlot = 'time' | 'actions'

export function resolveTrailingSlot({
  isHovered,
  isFocused,
}: {
  isHovered: boolean
  isFocused: boolean
}): TrailingSlot {
  return isHovered || isFocused ? 'actions' : 'time'
}

/**
 * 핀·잠금은 액션이기 전에 *상태*다. 켜져 있으면 호버하지 않아도 보여야
 * 훑을 때 상태가 읽힌다.
 */
export function shouldPinStatusStayVisible({
  isPinned,
  isLocked,
}: {
  isPinned: boolean
  isLocked: boolean
}): boolean {
  return isPinned || isLocked
}
