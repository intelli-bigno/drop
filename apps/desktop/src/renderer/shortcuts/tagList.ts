import type { KeyEventLike } from './types'
import { isPrimaryModifier } from './matchers'
import { matchesKey } from './keys'

// t 키로 노트별 태그 추가 다이얼로그
export const isOpenTagListShortcut = (event: KeyEventLike) =>
  matchesKey('openTagList', event.key) && !isPrimaryModifier(event)

// Cmd+T 키로 태그 관리 다이얼로그
export const isOpenTagManagementShortcut = (event: KeyEventLike) =>
  matchesKey('openTagManagement', event.key) && isPrimaryModifier(event)
