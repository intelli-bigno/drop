import type { KeyEventLike } from './types'
import { matchesKey, type ShortcutKeyId } from './keys'

// 휴지통/보관 단축키는 수식키 없이 눌렀을 때만 동작한다.
const isPlain = (event: KeyEventLike) => !event.metaKey && !event.ctrlKey && !event.altKey

const plainKey = (id: ShortcutKeyId) => (event: KeyEventLike) =>
  isPlain(event) && matchesKey(id, event.key)

// d 또는 ㅇ: 삭제 (휴지통으로)
export const isDeleteShortcut = plainKey('trashDelete')

// e 또는 ㄷ: 보관
export const isArchiveShortcut = plainKey('archive')

// r 또는 ㄱ: 복원
export const isRestoreShortcut = plainKey('restore')
