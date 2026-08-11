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

// Enter는 수식키에 따라 세 갈래로 갈라지므로 키 룩업이 아니라 아래에서 따로 처리한다.
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
  if (matchesKey('openFocused', event.key)) {
    if (isPrimaryModifier(event)) return 'createSibling'
    if (event.shiftKey) return 'replyToFocused'
    return 'openFocused'
  }

  for (const action of KEY_LOOKUP) {
    if ((KEYS[action] as readonly string[]).includes(event.key)) return action
  }

  return null
}
