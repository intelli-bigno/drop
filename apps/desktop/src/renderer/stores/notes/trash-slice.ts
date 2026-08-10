import type { StateCreator } from 'zustand'
import { supabase } from '../../lib/supabase'
import { useToastStore } from '../toast'
import type { NotesState, TrashSlice } from './types'
import type { NoteRow, Note, AttachmentRow, TagRow } from '@drop/shared'
import { noteRowToNote, attachmentRowToAttachment, tagRowToTag } from '@drop/shared'

export const createTrashSlice: StateCreator<NotesState, [], [], TrashSlice> = (set, get) => ({
  viewMode: 'active',
  trashedNotes: [],
  archivedNotes: [],

  setViewMode: (mode) => {
    set({ viewMode: mode })
    // 뷰 모드 변경 시 해당 데이터 로드
    if (mode === 'trash') {
      get().loadTrash()
    } else if (mode === 'archived') {
      get().loadArchived()
    }
  },

  // === Trash ===

  loadTrash: async () => {
    const { data: noteRows, error } = await supabase
      .from('notes')
      .select('*')
      .not('deleted_at', 'is', null)
      .order('deleted_at', { ascending: false })

    if (error) {
      console.error('[trash] loadTrash failed', error)
      return
    }

    if (!noteRows || noteRows.length === 0) {
      set({ trashedNotes: [] })
      return
    }

    // 첨부파일 로드
    const noteIds = noteRows.map((n) => n.id)
    const { data: attachmentRows } = await supabase
      .from('attachments')
      .select('*')
      .in('note_id', noteIds)

    // 태그 로드
    const { data: noteTagRows } = await supabase
      .from('note_tags')
      .select('note_id, tag_id, tags(*)')
      .in('note_id', noteIds)

    const attachmentMap = new Map<string, AttachmentRow[]>()
    for (const row of attachmentRows || []) {
      const list = attachmentMap.get(row.note_id) || []
      list.push(row)
      attachmentMap.set(row.note_id, list)
    }

    const tagMap = new Map<string, TagRow[]>()
    for (const row of noteTagRows || []) {
      const tag = row.tags as unknown as TagRow | null
      if (!tag) continue
      const list = tagMap.get(row.note_id) || []
      list.push(tag)
      tagMap.set(row.note_id, list)
    }

    const trashedNotes: Note[] = noteRows.map((row: NoteRow) => {
      const attachments = (attachmentMap.get(row.id) || []).map(attachmentRowToAttachment)
      const tags = (tagMap.get(row.id) || []).map(tagRowToTag)
      return noteRowToNote(row, attachments, tags)
    })

    set({ trashedNotes })
  },

  restoreNote: async (noteId) => {
    const { error } = await supabase
      .from('notes')
      .update({ deleted_at: null, is_deleted: false })
      .eq('id', noteId)

    if (error) {
      console.error('[trash] restoreNote failed', error)
      useToastStore.getState().showToast({
        message: '노트를 복원하지 못했습니다',
        variant: 'error',
      })
      return
    }

    // 휴지통에서 제거
    set((state) => ({
      trashedNotes: state.trashedNotes.filter((n) => n.id !== noteId),
    }))

    // active/보관 노트 목록 새로고침 (보관된 노트를 복원한 경우 보관함으로 돌아감)
    get().loadNotes()
    get().loadArchived()
  },

  permanentlyDeleteNote: async (noteId) => {
    const { error } = await supabase
      .from('notes')
      .delete()
      .eq('id', noteId)

    if (error) {
      console.error('[trash] permanentlyDeleteNote failed', error)
      useToastStore.getState().showToast({
        message: '노트를 영구 삭제하지 못했습니다',
        variant: 'error',
      })
      return
    }

    set((state) => ({
      trashedNotes: state.trashedNotes.filter((n) => n.id !== noteId),
    }))
  },

  emptyTrash: async () => {
    const trashedNotes = get().trashedNotes
    if (trashedNotes.length === 0) return

    const noteIds = trashedNotes.map((n) => n.id)
    const { error } = await supabase
      .from('notes')
      .delete()
      .in('id', noteIds)

    if (error) {
      console.error('[trash] emptyTrash failed', error)
      useToastStore.getState().showToast({
        message: '휴지통을 비우지 못했습니다',
        variant: 'error',
      })
      return
    }

    set({ trashedNotes: [] })
  },

  // === Archive ===

  loadArchived: async () => {
    const { data: noteRows, error } = await supabase
      .from('notes')
      .select('*')
      .not('archived_at', 'is', null)
      .is('deleted_at', null)
      .order('archived_at', { ascending: false })

    if (error) {
      console.error('[archive] loadArchived failed', error)
      return
    }

    if (!noteRows || noteRows.length === 0) {
      set({ archivedNotes: [] })
      return
    }

    // 첨부파일 로드
    const noteIds = noteRows.map((n) => n.id)
    const { data: attachmentRows } = await supabase
      .from('attachments')
      .select('*')
      .in('note_id', noteIds)

    // 태그 로드
    const { data: noteTagRows } = await supabase
      .from('note_tags')
      .select('note_id, tag_id, tags(*)')
      .in('note_id', noteIds)

    const attachmentMap = new Map<string, AttachmentRow[]>()
    for (const row of attachmentRows || []) {
      const list = attachmentMap.get(row.note_id) || []
      list.push(row)
      attachmentMap.set(row.note_id, list)
    }

    const tagMap = new Map<string, TagRow[]>()
    for (const row of noteTagRows || []) {
      const tag = row.tags as unknown as TagRow | null
      if (!tag) continue
      const list = tagMap.get(row.note_id) || []
      list.push(tag)
      tagMap.set(row.note_id, list)
    }

    const archivedNotes: Note[] = noteRows.map((row: NoteRow) => {
      const attachments = (attachmentMap.get(row.id) || []).map(attachmentRowToAttachment)
      const tags = (tagMap.get(row.id) || []).map(tagRowToTag)
      return noteRowToNote(row, attachments, tags)
    })

    set({ archivedNotes })
  },

  archiveNote: async (noteId) => {
    // Optimistic: active 목록에서 먼저 제거하고, 실패 시 롤백
    const prevNotes = get().notes

    set((state) => ({
      notes: state.notes.filter((n) => n.id !== noteId),
    }))

    const { error } = await supabase
      .from('notes')
      .update({ archived_at: new Date().toISOString() })
      .eq('id', noteId)

    if (error) {
      console.error('[archive] archiveNote failed', error)
      set({ notes: prevNotes })
      useToastStore.getState().showToast({
        message: '노트를 보관하지 못했습니다',
        variant: 'error',
      })
      return
    }

    useToastStore.getState().showToast({
      message: '노트가 보관되었습니다',
      actionLabel: '실행 취소',
      onAction: () => {
        get().unarchiveNote(noteId)
      },
    })
  },

  unarchiveNote: async (noteId) => {
    const { error } = await supabase
      .from('notes')
      .update({ archived_at: null })
      .eq('id', noteId)

    if (error) {
      console.error('[archive] unarchiveNote failed', error)
      useToastStore.getState().showToast({
        message: '보관을 해제하지 못했습니다',
        variant: 'error',
      })
      return
    }

    // archived 목록에서 제거
    set((state) => ({
      archivedNotes: state.archivedNotes.filter((n) => n.id !== noteId),
    }))

    // active 노트 목록 새로고침
    get().loadNotes()
  },
})
