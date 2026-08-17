import type { KeyEventLike } from './types'
import { isPrimaryModifier } from './matchers'
import { matchesKey } from './keys'

// Shift+C 로 포커스된 노트의 댓글 패널을 연다 (BRU-63).
// 맨 `c`는 내용 복사이고 ⌘C는 OS 복사라, "Comment"의 C를 쓰려면 Shift 뿐이다.
export const isOpenCommentsShortcut = (event: KeyEventLike) =>
  matchesKey('openComments', event.key) &&
  event.shiftKey &&
  !isPrimaryModifier(event) &&
  !event.altKey
