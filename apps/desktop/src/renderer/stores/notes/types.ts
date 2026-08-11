import type { Note, Attachment, Tag } from '@drop/shared'

// Notes slice
export interface NotesSlice {
  notes: Note[]
  selectedNoteId: string | null
  isLoading: boolean

  loadNotes: () => Promise<void>
  createNote: (initialContent?: string, parentId?: string) => Promise<Note>
  updateNote: (id: string, content: string) => Promise<void>
  updateNotePriority: (id: string, priority: number) => Promise<void>
  togglePinNote: (id: string) => Promise<void>
  deleteNote: (id: string) => Promise<void>
  selectNote: (id: string | null) => void
  subscribeToChanges: () => () => void
}

// Tags slice
export interface TagsSlice {
  allTags: Tag[]
  filterTag: string | null

  loadTags: () => Promise<void>
  addTagToNote: (noteId: string, tagName: string) => Promise<void>
  removeTagFromNote: (noteId: string, tagId: string) => Promise<void>
  setFilterTag: (tagName: string | null) => void
  updateTag: (tagId: string, newName: string) => Promise<void>
  deleteTag: (tagId: string) => Promise<void>
}

// Attachments slice
export interface AttachmentsSlice {
  addAttachment: (noteId: string, file: File) => Promise<Attachment | null>
  removeAttachment: (noteId: string, attachmentId: string) => Promise<void>
}

// Instagram slice
export interface InstagramSlice {
  createNoteWithInstagram: (url: string) => Promise<Note | null>
}

// YouTube slice
export interface YouTubeSlice {
  createNoteWithYouTube: (url: string) => Promise<Note | null>
}

// Lock slice
export interface LockSlice {
  // 일시 해제된 노트 ID들 (메모리에만 저장, 앱 재시작 시 초기화)
  temporarilyUnlockedNoteIds: Set<string>

  // 단일 노트 일시 해제
  temporarilyUnlockNote: (noteId: string) => void

  // 단일 노트 재잠금 (일시 해제 취소)
  relockNote: (noteId: string) => void

  // 전체 일시 해제
  temporarilyUnlockAll: () => void

  // 전체 재잠금
  relockAll: () => void

  // 완전 해제 (DB에 is_locked = false)
  permanentlyUnlockNote: (noteId: string) => Promise<void>

  // 잠금 설정 (DB에 is_locked = true)
  lockNote: (noteId: string) => Promise<void>

  // 잠긴 노트가 있는지 확인
  hasLockedNotes: () => boolean
}

// Category filter slice
export interface CategoryFilterSlice {
  categoryFilter: 'all' | 'link' | 'media' | 'files' | null
  setCategoryFilter: (filter: 'all' | 'link' | 'media' | 'files' | null) => void
}

// View mode for notes (active, archived, trash)
export type NoteViewMode = 'active' | 'archived' | 'trash'

// Trash & Archive slice
export interface TrashSlice {
  viewMode: NoteViewMode
  setViewMode: (mode: NoteViewMode) => void

  // Trash
  trashedNotes: Note[]
  loadTrash: () => Promise<void>
  restoreNote: (noteId: string) => Promise<void>
  permanentlyDeleteNote: (noteId: string) => Promise<void>
  emptyTrash: () => Promise<void>

  // Archive
  archivedNotes: Note[]
  loadArchived: () => Promise<void>
  archiveNote: (noteId: string) => Promise<void>
  unarchiveNote: (noteId: string) => Promise<void>
}

// Combined store state
export interface NotesState
  extends
    NotesSlice,
    TagsSlice,
    AttachmentsSlice,
    InstagramSlice,
    YouTubeSlice,
    LockSlice,
    CategoryFilterSlice,
    TrashSlice {}
