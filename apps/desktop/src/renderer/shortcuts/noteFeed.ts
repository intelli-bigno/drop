import type { KeyEventLike } from './types'
import { isPrimaryModifier } from './matchers'
import { KEYS, matchesKey } from './keys'

export type NoteFeedShortcutAction =
  | 'clearFocus'
  | 'focusNext'
  | 'focusPrev'
  | 'openFocused'
  | 'deleteFocused'
  | 'replyToFocused'
  | 'createSibling'
  | 'copyFocused'
  | 'togglePin'
  | 'setPriority0'
  | 'setPriority1'
  | 'setPriority2'
  | 'setPriority3'

// Enter는 수식키에 따라 갈라지므로 키 룩업이 아니라 아래에서 따로 처리한다.
const KEY_LOOKUP: NoteFeedShortcutAction[] = [
  'clearFocus',
  'focusNext',
  'focusPrev',
  'deleteFocused',
  'copyFocused',
  'togglePin',
  'setPriority0',
  'setPriority1',
  'setPriority2',
  'setPriority3',
]

export function resolveNoteFeedShortcut(event: KeyEventLike): NoteFeedShortcutAction | null {
  // Enter는 노트를 "만드는" 키다. 맨 Enter로는 편집이 열리지 않는다 (BRU-53).
  if (matchesKey('createSibling', event.key)) {
    if (isPrimaryModifier(event)) return 'createSibling'
    if (event.shiftKey) return 'replyToFocused'
    return null
  }

  // 편집 진입은 `/`·`i`뿐이고, 수식키가 붙으면 다른 명령이다 (⌘/ = 치트시트).
  if (matchesKey('openFocused', event.key)) {
    if (isPrimaryModifier(event) || event.shiftKey || event.altKey) return null
    return 'openFocused'
  }

  // Shift가 눌린 글쇠는 피드 액션이 아니다 (BRU-63).
  // 한글 입력 상태에서 Shift+ㅊ(댓글 열기)는 `ㅊ` 그대로 찍혀 `c`(복사)와 구분이 안 된다 —
  // Shift를 걸러야 댓글을 열 때마다 클립보드가 덮이는 일이 없다.
  if (event.shiftKey) return null

  for (const action of KEY_LOOKUP) {
    if ((KEYS[action] as readonly string[]).includes(event.key)) return action
  }

  return null
}
