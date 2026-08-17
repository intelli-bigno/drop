import type { KeyEventLike } from './types'
import { isPrimaryModifier } from './matchers'
import { matchesKey } from './keys'
import { isPlainKey } from './matchers'

export const isCreateNoteShortcut = (event: KeyEventLike) => matchesKey('createNote', event.key)

export const isSearchShortcut = (event: KeyEventLike) =>
  isPrimaryModifier(event) && matchesKey('search', event.key)

// ⌘/ 또는 ? 로 단축키 치트시트.
// 맨 `/`는 편집 진입 키라 여기서 잡지 않는다 (BRU-53).
// '?' 는 수식키 없이 눌리므로 텍스트 입력 중에는 호출부에서 걸러야 한다.
export const isCheatSheetShortcut = (event: KeyEventLike) =>
  (isPrimaryModifier(event) && matchesKey('cheatSheet', event.key)) ||
  (isPlainKey(event) && matchesKey('cheatSheetAlt', event.key))
