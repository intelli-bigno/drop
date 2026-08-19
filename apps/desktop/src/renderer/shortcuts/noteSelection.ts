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
