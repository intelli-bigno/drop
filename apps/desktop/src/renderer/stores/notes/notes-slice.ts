import type { StateCreator } from 'zustand'
import { supabase } from '../../lib/supabase'
import { useAuthStore } from '../auth'
import { useToastStore } from '../toast'
import { tagRowToTag, noteRowToNote, attachmentRowToAttachment } from '@drop/shared'
import type { NoteRow, AttachmentRow, TagRow, Attachment, Tag } from '@drop/shared'
import type { NotesState, NotesSlice } from './types'
import { calculateNoteCategories } from '../../lib/note-category-utils'

export const createNotesSlice: StateCreator<NotesState, [], [], NotesSlice> = (set, get) => ({
  notes: [],
  selectedNoteId: null,
  isLoading: false,
  pendingDeleteNoteId: null,

  // 삭제는 항상 확인을 거친다 — 단축키든 버튼이든 여기로 모인다 (BRU-24)
  requestDeleteNote: (id) => set({ pendingDeleteNoteId: id }),

  cancelDeleteNote: () => set({ pendingDeleteNoteId: null }),

  confirmDeleteNote: async () => {
    const id = get().pendingDeleteNoteId
    if (!id) return
    set({ pendingDeleteNoteId: null })
    await get().deleteNote(id)
  },

  loadNotes: async () => {
    set({ isLoading: true })
    try {
      // 노트 로드
      const { data: noteRows, error: notesError } = await supabase
        .from('notes')
        .select('*')
        .is('deleted_at', null)
        .is('archived_at', null)
        .order('is_pinned', { ascending: false })
        .order('pinned_at', { ascending: false, nullsFirst: false })
        .order('created_at', { ascending: false })

      if (notesError) throw notesError

      // 모든 첨부파일 로드
      const noteIds = noteRows?.map((n) => n.id) ?? []
      let attachmentRows: AttachmentRow[] = []

      if (noteIds.length > 0) {
        const { data, error: attachmentsError } = await supabase
          .from('attachments')
          .select('*')
          .in('note_id', noteIds)
          .order('created_at', { ascending: true })

        if (attachmentsError) throw attachmentsError
        attachmentRows = (data ?? []) as AttachmentRow[]
      }

      // 모든 태그 관계 로드
      interface NoteTagWithTag {
        note_id: string
        tag_id: string
        tags: TagRow
      }
      let noteTagRows: NoteTagWithTag[] = []
      if (noteIds.length > 0) {
        const { data, error: noteTagsError } = await supabase
          .from('note_tags')
          .select('note_id, tag_id, tags(*)')
          .in('note_id', noteIds)

        if (noteTagsError) throw noteTagsError
        noteTagRows = (data ?? []) as unknown as NoteTagWithTag[]
      }

      // 첨부파일을 노트별로 그룹화
      const attachmentsByNote = new Map<string, Attachment[]>()
      for (const row of attachmentRows) {
        const attachment = attachmentRowToAttachment(row)
        const existing = attachmentsByNote.get(attachment.noteId) ?? []
        existing.push(attachment)
        attachmentsByNote.set(attachment.noteId, existing)
      }

      // 태그를 노트별로 그룹화
      const tagsByNote = new Map<string, Tag[]>()
      for (const row of noteTagRows) {
        const tag = tagRowToTag(row.tags)
        const existing = tagsByNote.get(row.note_id) ?? []
        existing.push(tag)
        tagsByNote.set(row.note_id, existing)
      }

      // 노트와 첨부파일, 태그 결합
      const notes = (noteRows ?? []).map((row) =>
        noteRowToNote(
          row as NoteRow,
          attachmentsByNote.get(row.id) ?? [],
          tagsByNote.get(row.id) ?? []
        )
      )

      set({ notes, isLoading: false })

      // 카드 뱃지에 쓸 댓글 *개수*만 함께 읽는다 — 본문은 패널을 열 때 읽는다.
      // 댓글은 노트가 아니므로 `notes` 배열에는 들어가지 않는다 (BRU-63).
      void get().loadCommentCounts(noteIds)
    } catch (error) {
      console.error('Failed to load notes:', error)
      set({ isLoading: false })
      useToastStore.getState().showToast({
        message: '노트를 불러오지 못했습니다',
        variant: 'error',
        actionLabel: '재시도',
        onAction: () => {
          get().loadNotes()
        },
      })
    }
  },

  createNote: async (initialContent = '', parentId?: string) => {
    // Get cached user from auth store (no network request!)
    const user = useAuthStore.getState().user
    if (!user) {
      console.error('[notes] createNote: user not authenticated')
      return {
        id: '',
        displayId: 0,
        content: '',
        parentId: null,
        attachments: [],
        tags: [],
        createdAt: new Date(),
        updatedAt: new Date(),
        source: 'desktop' as const,
        isDeleted: false,
        hasLink: false,
        hasMedia: false,
        hasFiles: false,
        isLocked: false,
        deletedAt: null,
        archivedAt: null,
        priority: 0,
        isPinned: false,
        pinnedAt: null,
        linearIssueUrl: null,
        linearIssueKey: null,
        linearExportedAt: null,
        projectId: null,
      }
    }

    const id = crypto.randomUUID()
    const now = new Date()
    const categories = calculateNoteCategories(initialContent, [])
    // displayId는 DB에서 트리거로 생성되므로 optimistic 노트에는 임시로 가장 높은 값 + 1 사용
    const maxDisplayId = Math.max(0, ...get().notes.map((n) => n.displayId))
    const optimisticNote = {
      id,
      displayId: maxDisplayId + 1,
      content: initialContent,
      parentId: parentId ?? null,
      attachments: [],
      tags: [],
      createdAt: now,
      updatedAt: now,
      source: 'desktop' as const,
      isDeleted: false,
      hasLink: categories.hasLink,
      hasMedia: categories.hasMedia,
      hasFiles: categories.hasFiles,
      isLocked: false,
      deletedAt: null,
      archivedAt: null,
      priority: 0,
      isPinned: false,
      pinnedAt: null,
      // 새 노트는 당연히 아직 반출되지 않았다 (BRU-45)
      linearIssueUrl: null,
      linearIssueKey: null,
      linearExportedAt: null,
      // 새 노트는 아직 프로젝트가 없다 (BRU-83)
      projectId: null,
    }

    set((state) => ({
      notes: [optimisticNote, ...state.notes],
      selectedNoteId: id,
    }))
    console.info('[notes] createNote optimistic', { id, parentId })

    const { data, error } = await supabase
      .from('notes')
      .insert({
        id,
        content: initialContent,
        parent_id: parentId ?? null,
        source: 'desktop',
        user_id: user.id,
        has_link: categories.hasLink,
        has_media: categories.hasMedia,
        has_files: categories.hasFiles,
      })
      .select()
      .single()

    if (error) {
      console.error('[notes] createNote supabase error', error)
      set((state) => ({
        notes: state.notes.filter((note) => note.id !== id),
        selectedNoteId: state.selectedNoteId === id ? null : state.selectedNoteId,
      }))
      throw error
    }

    const note = noteRowToNote(data as NoteRow)
    set((state) => ({
      notes: state.notes.map((item) => (item.id === id ? note : item)),
    }))
    console.info('[notes] createNote confirmed', { id })
    return note
  },

  updateNote: async (id, content) => {
    const existingNote = get().notes.find((n) => n.id === id)
    if (!existingNote) return

    // 카테고리 재계산 (has_link만 content에 영향받음)
    const categories = calculateNoteCategories(content, existingNote.attachments)
    const updateData: Record<string, unknown> = { content }

    // has_link가 변경된 경우에만 업데이트
    if (existingNote.hasLink !== categories.hasLink) {
      updateData.has_link = categories.hasLink
    }

    const { data, error } = await supabase
      .from('notes')
      .update(updateData)
      .eq('id', id)
      .select()
      .single()

    if (error) throw error

    set((state) => ({
      notes: state.notes.map((n) =>
        n.id === id
          ? { ...n, content, hasLink: categories.hasLink, updatedAt: new Date(data.updated_at) }
          : n
      ),
    }))
  },

  deleteNote: async (id) => {
    // Optimistic: 목록에서 먼저 제거하고, 실패 시 롤백 (보관함 뷰에서의 삭제도 포함)
    const prevNotes = get().notes
    const prevArchivedNotes = get().archivedNotes
    const prevSelectedNoteId = get().selectedNoteId

    set((state) => ({
      notes: state.notes.filter((n) => n.id !== id),
      archivedNotes: state.archivedNotes.filter((n) => n.id !== id),
      selectedNoteId: state.selectedNoteId === id ? null : state.selectedNoteId,
    }))

    const { error } = await supabase
      .from('notes')
      .update({ deleted_at: new Date().toISOString(), is_deleted: true })
      .eq('id', id)

    if (error) {
      console.error('[notes] deleteNote failed', error)
      set({
        notes: prevNotes,
        archivedNotes: prevArchivedNotes,
        selectedNoteId: prevSelectedNoteId,
      })
      useToastStore.getState().showToast({
        message: '노트를 삭제하지 못했습니다',
        variant: 'error',
      })
      return
    }

    useToastStore.getState().showToast({
      message: '노트가 삭제되었습니다',
      actionLabel: '실행 취소',
      onAction: () => {
        get().restoreNote(id)
      },
    })
  },

  selectNote: (id) => {
    set({ selectedNoteId: id })
  },

  updateNotePriority: async (id, priority) => {
    const { error } = await supabase.from('notes').update({ priority }).eq('id', id)

    if (error) {
      console.error('[notes] updateNotePriority failed', error)
      useToastStore.getState().showToast({
        message: '우선순위를 변경하지 못했습니다',
        variant: 'error',
      })
      return
    }

    set((state) => ({
      notes: state.notes.map((n) => (n.id === id ? { ...n, priority } : n)),
    }))
  },

  togglePinNote: async (id) => {
    const note = get().notes.find((n) => n.id === id)
    if (!note) return

    const newPinned = !note.isPinned
    const pinnedAt = newPinned ? new Date().toISOString() : null

    const { error } = await supabase
      .from('notes')
      .update({ is_pinned: newPinned, pinned_at: pinnedAt })
      .eq('id', id)

    if (error) {
      console.error('[notes] togglePinNote failed', error)
      useToastStore.getState().showToast({
        message: newPinned ? '노트를 고정하지 못했습니다' : '고정을 해제하지 못했습니다',
        variant: 'error',
      })
      return
    }

    set((state) => ({
      notes: state.notes.map((n) =>
        n.id === id
          ? { ...n, isPinned: newPinned, pinnedAt: pinnedAt ? new Date(pinnedAt) : null }
          : n
      ),
    }))
  },

  subscribeToChanges: () => {
    const channel = supabase
      .channel('notes-changes')
      .on('postgres_changes', { event: '*', schema: 'public', table: 'notes' }, async (payload) => {
        const { eventType, new: newRow, old: oldRow } = payload

        if (eventType === 'INSERT') {
          // realtime에서는 연관 데이터(태그, 첨부파일)를 포함하지 않으므로 빈 배열로 초기화
          const note = noteRowToNote(newRow as NoteRow, [], [])
          set((state) => {
            // 이미 존재하면 무시 (로컬에서 생성한 경우)
            if (state.notes.some((n) => n.id === note.id)) return state
            return { notes: [note, ...state.notes] }
          })
        } else if (eventType === 'UPDATE') {
          const row = newRow as NoteRow
          // 삭제되거나 보관된 노트는 active 목록에서 제거
          if (row.deleted_at || row.archived_at) {
            set((state) => ({
              notes: state.notes.filter((n) => n.id !== row.id),
            }))
          } else {
            set((state) => ({
              notes: state.notes.map((n) =>
                n.id === row.id
                  ? {
                      ...n,
                      content: row.content ?? '',
                      updatedAt: new Date(row.updated_at),
                      isPinned: row.is_pinned ?? false,
                      pinnedAt: row.pinned_at ? new Date(row.pinned_at) : null,
                    }
                  : n
              ),
            }))
          }
        } else if (eventType === 'DELETE') {
          const id = (oldRow as { id: string }).id
          set((state) => ({
            notes: state.notes.filter((n) => n.id !== id),
          }))
        }
      })
      .subscribe()

    return () => {
      supabase.removeChannel(channel)
    }
  },
})
