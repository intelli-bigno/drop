import type { KeyEventLike } from './types'
import { matchesKey } from './keys'

export const isToggleLockShortcut = (event: KeyEventLike) =>
  event.metaKey && matchesKey('toggleLock', event.key)
