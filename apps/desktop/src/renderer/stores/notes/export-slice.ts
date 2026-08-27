import type { StateCreator } from 'zustand'
import { supabase } from '../../lib/supabase'
import { useToastStore } from '../toast'
import type { NotesState, ExportSlice } from './types'
import { restoreNoteFields } from './active-list'

/**
 * Linear 반출 표시 (BRU-45).
 *
 * 이슈를 **만드는** 것은 앱의 일이 아니다 — 에이전트가 Linear MCP로 만들고
 * `mcp_set_note_export`로 URL을 적는다. 앱은 그 표시를 읽어 보여 주고,
 * 잘못된 표시를 걷어내는 것까지만 한다. Linear 토큰을 앱에 두지 않기 위해서다.
 *
 * 반출된 노트는 기본 목록에서 빠진다. 다시 찾으려면 `showExported`를 켠다 —
 * 되돌릴 방법이 없으면 잘못 반출한 노트가 영영 안 보인다.
 */
export const createExportSlice: StateCreator<NotesState, [], [], ExportSlice> = (set, get) => ({
  showExported: false,

  setShowExported: (showExported) => set({ showExported }),

  clearNoteExport: async (noteId) => {
    const prevNote = get().notes.find((n) => n.id === noteId)

    // 낙관적 갱신 — 표시를 먼저 걷어낸다. 실패하면 해당 노트만 되돌린다 (BRU-114)
    set((state) => ({
      notes: state.notes.map((note) =>
        note.id === noteId
          ? { ...note, linearIssueUrl: null, linearIssueKey: null, linearExportedAt: null }
          : note
      ),
    }))

    const { error } = await supabase
      .from('notes')
      .update({ linear_issue_url: null, linear_issue_key: null, linear_exported_at: null })
      .eq('id', noteId)

    if (error) {
      console.error('[export] clearNoteExport failed', error)
      set((state) => ({
        notes: prevNote ? restoreNoteFields(state.notes, prevNote) : state.notes,
      }))
      useToastStore.getState().showToast({
        message: '반출 표시를 지우지 못했습니다',
        variant: 'error',
      })
      return
    }

    useToastStore.getState().showToast({ message: '반출 표시를 지웠습니다' })
  },
})
