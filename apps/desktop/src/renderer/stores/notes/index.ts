import { create } from 'zustand'
import { createNotesSlice } from './notes-slice'
import { createCommentsSlice } from './comments-slice'
import { createTagsSlice } from './tags-slice'
import { createProjectsSlice } from './projects-slice'
import { createAttachmentsSlice } from './attachments-slice'
import { createInstagramSlice } from './instagram-slice'
import { createYouTubeSlice } from './youtube-slice'
import { createRevisionsSlice } from './revisions-slice'
import { createLockSlice, createCategoryFilterSlice } from './lock-slice'
import { createInboxSlice } from './inbox-slice'
import { createExportSlice } from './export-slice'
import { createTodoSlice } from './todo-slice'
import { createTrashSlice } from './trash-slice'
import type { NotesState } from './types'
export type { NotesState, NoteViewMode } from './types'

export const useNotesStore = create<NotesState>()((...a) => ({
  ...createNotesSlice(...a),
  ...createCommentsSlice(...a),
  ...createTagsSlice(...a),
  ...createProjectsSlice(...a),
  ...createAttachmentsSlice(...a),
  ...createInstagramSlice(...a),
  ...createYouTubeSlice(...a),
  ...createRevisionsSlice(...a),
  ...createLockSlice(...a),
  ...createCategoryFilterSlice(...a),
  ...createInboxSlice(...a),
  ...createExportSlice(...a),
  ...createTodoSlice(...a),
  ...createTrashSlice(...a),
}))
