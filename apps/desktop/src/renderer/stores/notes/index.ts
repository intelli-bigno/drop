import { create } from 'zustand'
import { createNotesSlice } from './notes-slice'
import { createTagsSlice } from './tags-slice'
import { createAttachmentsSlice } from './attachments-slice'
import { createInstagramSlice } from './instagram-slice'
import { createYouTubeSlice } from './youtube-slice'
import { createLockSlice, createCategoryFilterSlice } from './lock-slice'
import { createTrashSlice } from './trash-slice'
import type { NotesState } from './types'
export type { NotesState, NoteViewMode } from './types'

export const useNotesStore = create<NotesState>()((...a) => ({
  ...createNotesSlice(...a),
  ...createTagsSlice(...a),
  ...createAttachmentsSlice(...a),
  ...createInstagramSlice(...a),
  ...createYouTubeSlice(...a),
  ...createLockSlice(...a),
  ...createCategoryFilterSlice(...a),
  ...createTrashSlice(...a),
}))
