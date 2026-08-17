import { create } from 'zustand'
import { createNotesSlice } from './notes-slice'
import { createCommentsSlice } from './comments-slice'
import { createTagsSlice } from './tags-slice'
import { createAttachmentsSlice } from './attachments-slice'
import { createInstagramSlice } from './instagram-slice'
import { createYouTubeSlice } from './youtube-slice'
import { createRevisionsSlice } from './revisions-slice'
import { createLockSlice, createCategoryFilterSlice } from './lock-slice'
import { createInboxSlice } from './inbox-slice'
import { createTrashSlice } from './trash-slice'
import type { NotesState } from './types'
export type { NotesState, NoteViewMode } from './types'

export const useNotesStore = create<NotesState>()((...a) => ({
  ...createNotesSlice(...a),
  ...createCommentsSlice(...a),
  ...createTagsSlice(...a),
  ...createAttachmentsSlice(...a),
  ...createInstagramSlice(...a),
  ...createYouTubeSlice(...a),
  ...createRevisionsSlice(...a),
  ...createLockSlice(...a),
  ...createCategoryFilterSlice(...a),
  ...createInboxSlice(...a),
  ...createTrashSlice(...a),
}))
