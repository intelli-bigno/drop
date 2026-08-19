// 한 줄 카드의 오른쪽 끝 자리(BRU-46).
//
// 평소에는 상대 시간이 있고, 마우스를 올리면 같은 자리가 액션 버튼으로 바뀐다.
// 키보드 포커스만으로는 바뀌지 않는다 (BRU-82) — 훑기만 해도 아이콘이 켜지면
// 목록이 시끄럽다. 키보드로 액션에 닿는 길은 두 갈래로 따로 열려 있다:
// 단축키(p·Delete·e·⇧C·⌘L·t)와, Tab으로 버튼에 포커스가 들어갔을 때 켜지는
// CSS `.note-card:focus-within` 규칙이다.
//
// 자리 자체는 CSS가 겹쳐 그린다(액션은 시간 위에 absolute) — 그래야 버튼 수와
// 무관하게 줄 폭이 흔들리지 않는다.

import type { NoteViewMode } from '../stores/notes/types'

export type TrailingSlot = 'time' | 'actions'

export function resolveTrailingSlot({ isHovered }: { isHovered: boolean }): TrailingSlot {
  return isHovered ? 'actions' : 'time'
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

/** 액션 버튼 한 변의 길이(px). 밀도 규칙(BRU-56)에 맞춘 값 — CSS와 같이 움직인다. */
export const ACTION_BUTTON_SIZE = 24
/** 액션 버튼 사이 간격(px) */
export const ACTION_BUTTON_GAP = 2

/**
 * 보기 모드가 그릴 수 있는 액션 버튼의 **최대** 개수.
 * 실제로 몇 개가 그려지는지(잠긴 노트는 더 적다)와 무관하게 이 값을 쓴다.
 */
const MAX_ACTION_BUTTONS: Record<NoteViewMode, number> = {
  // 고정 · 잠금 · 답글 · 댓글 · 편집 기록 · 보관 · 삭제
  active: 7,
  // 보관 해제 · 삭제
  archived: 2,
  // 복원 · 영구 삭제
  trash: 2,
}

/**
 * 오른쪽 끝 자리가 **미리 비워 둬야 할** 폭(px) — BRU-57.
 *
 * 액션은 시간 위에 absolute로 겹쳐 그리는데, 부모 상자가 시간 폭밖에 안 되면
 * 오버레이가 왼쪽으로 흘러나가 태그를 덮는다. 부모에 이 폭만큼 `min-width`를
 * 주면 오버레이가 상자 안에 들어와 태그를 침범할 수 없다.
 *
 * 실제 버튼 수가 아니라 보기 모드별 최대치로 계산하는 것이 핵심이다 —
 * 카드마다 예약 폭이 달라지면 BRU-46의 "줄 폭이 버튼 수에 따라 흔들리지
 * 않는다"가 깨진다.
 */
export function reservedActionsWidth(viewMode: NoteViewMode): number {
  const count = MAX_ACTION_BUTTONS[viewMode]
  return count * ACTION_BUTTON_SIZE + (count - 1) * ACTION_BUTTON_GAP
}
