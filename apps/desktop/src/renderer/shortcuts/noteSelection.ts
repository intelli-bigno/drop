import type { KeyEventLike } from './types'
import { isPlainKey } from './matchers'
import { matchesKey } from './keys'

// 비주얼 선택 키 해석 (BRU-80).
// 피드 리졸버(noteFeed.ts)는 Shift가 눌리면 null을 돌려주므로(BRU-63) 겹치지 않는다 —
// Shift+J/K가 남아 있던 자리라 선택 확장을 여기에 둔다.

export type NoteSelectionShortcutAction =
  | 'enterVisual'
  | 'extendNext'
  | 'extendPrev'
  | 'exitVisual'

export function resolveNoteSelectionShortcut(
  event: KeyEventLike
): NoteSelectionShortcutAction | null {
  // ⌘K(검색)·⌥ 조합은 다른 명령이다
  if (!isPlainKey(event)) return null

  if (event.key === 'Escape') return 'exitVisual'

  if (event.shiftKey) {
    if (matchesKey('extendSelectionNext', event.key)) return 'extendNext'
    if (matchesKey('extendSelectionPrev', event.key)) return 'extendPrev'
    return null
  }

  if (matchesKey('enterVisualSelection', event.key)) return 'enterVisual'

  return null
}

// Esc 한 번이 무엇을 벗기는지 (BRU-109).
// 피드에는 Esc 핸들러가 둘이다 — 카드가 있는 컨테이너의 React onKeyDown과 window의 전역
// keydown. 둘이 서로 다른 판단을 하면 포커스가 어디에 있느냐에 따라 Esc가 죽는 자리가 생긴다.
// 판단을 여기 한 군데로 모은다.
export type FeedEscapeAction = 'ignore' | 'clearSelection' | 'clearFocus' | 'none'

export interface FeedEscapeState {
  /** 일괄 삭제 확인 다이얼로그가 떠 있는가 */
  isConfirmDialogOpen: boolean
  hasSelection: boolean
  hasFocus: boolean
}

export function resolveFeedEscape(state: FeedEscapeState): FeedEscapeAction {
  // 확인 다이얼로그가 떠 있으면 Esc는 다이얼로그의 것이다 —
  // 선택만 풀면 "0개 삭제" 문구가 남은 채 확인해도 아무것도 안 지워진다.
  if (state.isConfirmDialogOpen) return 'ignore'
  // 한 번에 한 겹씩. 선택 중이면 포커스까지 잃지 않는다 — 이어서 j/k를 칠 수 있어야 한다 (BRU-80).
  if (state.hasSelection) return 'clearSelection'
  if (state.hasFocus) return 'clearFocus'
  return 'none'
}
