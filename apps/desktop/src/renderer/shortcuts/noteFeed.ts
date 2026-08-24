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
  | 'copyFocusedReference'
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

/**
 * 복사 글쇠인지 — Shift가 눌리면 `c`가 `C`로 오므로 대소문자를 접어서 본다.
 * 한글 별칭 `ㅊ`는 Shift를 눌러도 그대로 찍혀 접을 것이 없다.
 */
function matchesCopyKey(eventKey: string): boolean {
  const folded = eventKey.toLowerCase()
  return (KEYS.copyFocused as readonly string[]).includes(folded)
}

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

  // 복사는 두 갈래다 (BRU-104). ⌘C = 내용만, ⌘⇧C = 참조 링크.
  // 맨 `c`는 하위 호환으로 내용 복사에 남는다 (아래 KEY_LOOKUP).
  // Shift 검사보다 먼저 와야 한다 — 아래에서 Shift를 통째로 걸러내기 때문이다.
  if (isPrimaryModifier(event) && matchesCopyKey(event.key)) {
    if (event.altKey) return null
    return event.shiftKey ? 'copyFocusedReference' : 'copyFocused'
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
