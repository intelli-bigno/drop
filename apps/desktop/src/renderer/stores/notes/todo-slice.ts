import type { StateCreator } from 'zustand'
import { supabase } from '../../lib/supabase'
import { useToastStore } from '../toast'
import type { NotesState, TodoSlice } from './types'
import { restoreNoteFields } from './active-list'
import { withNoteType, toggleCompleted, toTodoStatePatch, applyTodoState } from '../../lib/note-todo'

/**
 * 노트 타입과 할일 완료 (BRU-175).
 *
 * 두 동작 모두 **본문을 건드리지 않는다** — 분류를 옮기거나 상태를 뒤집는 것은
 * 노트를 고친 것이 아니다. 그래서 note_revisions 스냅샷도 남지 않는다.
 *
 * 상태 전이 규칙은 `lib/note-todo.ts`에 있다. 낙관적 갱신은 화면이 취할 다음
 * 모습과 서버에 보낼 값이 같아야 하므로, 둘을 같은 함수에서 뽑는다 (BRU-114).
 */
export const createTodoSlice: StateCreator<NotesState, [], [], TodoSlice> = (set, get) => ({
  todoFilter: null,

  setTodoFilter: (todoFilter) => set({ todoFilter }),

  setNoteType: async (noteId, type) => {
    const prevNote = get().notes.find((n) => n.id === noteId)
    if (!prevNote) return

    const next = withNoteType(prevNote, type)

    set((state) => ({ notes: applyTodoState(state.notes, noteId, next) }))

    const { error } = await supabase
      .from('notes')
      .update(toTodoStatePatch(next))
      .eq('id', noteId)

    if (error) {
      console.error('[todo] setNoteType failed', error)
      set((state) => ({ notes: restoreNoteFields(state.notes, prevNote) }))
      useToastStore.getState().showToast({
        message: '노트 종류를 바꾸지 못했습니다',
        variant: 'error',
      })
      return
    }

    useToastStore.getState().showToast({
      message: type === 'todo' ? '할일로 바꿨습니다' : '일반 노트로 되돌렸습니다',
    })
  },

  toggleNoteCompleted: async (noteId) => {
    const prevNote = get().notes.find((n) => n.id === noteId)
    if (!prevNote) return

    const next = toggleCompleted(prevNote, new Date())
    // 할일이 아니면 전이 규칙이 같은 객체를 돌려준다 — 서버에 보낼 것이 없다
    if (next === prevNote) return

    set((state) => ({ notes: applyTodoState(state.notes, noteId, next) }))

    const { error } = await supabase
      .from('notes')
      .update(toTodoStatePatch(next))
      .eq('id', noteId)

    if (error) {
      console.error('[todo] toggleNoteCompleted failed', error)
      set((state) => ({ notes: restoreNoteFields(state.notes, prevNote) }))
      useToastStore.getState().showToast({
        message: '완료 표시를 바꾸지 못했습니다',
        variant: 'error',
      })
    }
    // 성공 토스트는 띄우지 않는다 — 체크박스가 즉시 바뀌는 것이 이미 피드백이고,
    // 여러 개를 연달아 체크할 때 토스트가 쌓이면 오히려 방해가 된다.
  },
})
