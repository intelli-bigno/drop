import type { KeyEventLike } from './types'

export const isPrimaryModifier = (event: KeyEventLike) => event.metaKey || event.ctrlKey

// 수식키 없이 눌린 키. Shift는 세지 않는다 — `?` 처럼 Shift로만 찍히는 글쇠가 있다.
export const isPlainKey = (event: KeyEventLike) =>
  !event.metaKey && !event.ctrlKey && !event.altKey
