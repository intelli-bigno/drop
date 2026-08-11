import type { StateCreator } from 'zustand'
import { supabase } from '../../lib/supabase'
import { useToastStore } from '../toast'
import { noteRevisionRowToNoteRevision } from '@drop/shared'
import type { NoteRevisionRow, NoteRevision } from '@drop/shared'
import type { NotesState, RevisionsSlice } from './types'

// 편집 히스토리는 DB 트리거가 기록한다 — 여기서는 읽기와 복원만 한다.
// 복원도 일반 노트 수정이라, 복원 직전 내용이 다시 히스토리에 쌓인다 (복원의 취소가 가능).
export const createRevisionsSlice: StateCreator<NotesState, [], [], RevisionsSlice> = (
  set,
  get
) => ({
  revisionsByNote: {},
  isRevisionsLoading: false,
  historyNoteId: null,

  openHistory: (noteId: string) => {
    set({ historyNoteId: noteId })
    get().loadRevisions(noteId)
  },

  closeHistory: () => set({ historyNoteId: null }),

  loadRevisions: async (noteId: string) => {
    set({ isRevisionsLoading: true })
    try {
      const { data, error } = await supabase
        .from('note_revisions')
        .select('*')
        .eq('note_id', noteId)
        .order('created_at', { ascending: false })

      if (error) throw error

      const revisions: NoteRevision[] = ((data ?? []) as NoteRevisionRow[]).map(
        noteRevisionRowToNoteRevision
      )

      set((state) => ({
        revisionsByNote: { ...state.revisionsByNote, [noteId]: revisions },
        isRevisionsLoading: false,
      }))
    } catch (error) {
      console.error('[revisions] load failed', error)
      set({ isRevisionsLoading: false })
      useToastStore.getState().showToast({
        message: '편집 기록을 불러오지 못했습니다',
        variant: 'error',
        actionLabel: '재시도',
        onAction: () => {
          get().loadRevisions(noteId)
        },
      })
    }
  },

  restoreRevision: async (noteId: string, content: string) => {
    try {
      await get().updateNote(noteId, content)
      // 복원 자체가 하나의 편집이므로 목록을 다시 읽어 최신 상태를 반영한다.
      await get().loadRevisions(noteId)
      useToastStore.getState().showToast({
        message: '이전 내용으로 되돌렸습니다',
      })
    } catch (error) {
      console.error('[revisions] restore failed', error)
      useToastStore.getState().showToast({
        message: '되돌리지 못했습니다',
        variant: 'error',
      })
    }
  },
})
