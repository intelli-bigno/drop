import type { KeyEventLike } from './types'
import { isPrimaryModifier } from './matchers'
import { matchesKey } from './keys'

export const isCreateNoteShortcut = (event: KeyEventLike) => matchesKey('createNote', event.key)

export const isSearchShortcut = (event: KeyEventLike) =>
  isPrimaryModifier(event) && matchesKey('search', event.key)
