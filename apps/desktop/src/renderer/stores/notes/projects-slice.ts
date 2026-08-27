import type { StateCreator } from 'zustand'
import { supabase } from '../../lib/supabase'
import { useAuthStore } from '../auth'
import { useToastStore } from '../toast'
import { projectRowToProject } from '@drop/shared'
import type { ProjectRow } from '@drop/shared'
import type { NotesState, ProjectsSlice } from './types'
import { restoreNoteFields } from './active-list'

/**
 * 프로젝트 (BRU-83) — 노트를 묶는 상위 분류.
 *
 * 태그와 다른 점 둘:
 * 1) 노트는 프로젝트 **하나**에만 속한다. 지정은 `notes.project_id` 갱신 하나로 끝난다
 *    (태그처럼 연결 테이블이 없다).
 * 2) 이름을 소문자로 뭉개지 않는다 — 사람이 적은 대로 보관한다.
 */
export const createProjectsSlice: StateCreator<NotesState, [], [], ProjectsSlice> = (set, get) => ({
  allProjects: [],
  filterProjectId: null,

  loadProjects: async () => {
    const { data, error } = await supabase
      .from('projects')
      .select('*')
      .order('created_at', { ascending: false })

    if (error) {
      console.error('[projects] loadProjects failed', error)
      return
    }

    set({ allProjects: (data ?? []).map((row) => projectRowToProject(row as ProjectRow)) })
  },

  createProject: async (name) => {
    const trimmed = name.trim()
    if (!trimmed) return null

    const user = useAuthStore.getState().user
    if (!user) {
      console.error('[projects] createProject: user not authenticated')
      return null
    }

    const { data, error } = await supabase
      .from('projects')
      .insert({ name: trimmed, user_id: user.id })
      .select()
      .single()

    if (error) {
      console.error('[projects] createProject failed', error)
      useToastStore.getState().showToast({
        // 유일 인덱스에 걸리는 경우가 대부분이다 — 같은 이름이 이미 있다는 뜻이다
        message: '프로젝트를 만들지 못했습니다',
        variant: 'error',
      })
      return null
    }

    const project = projectRowToProject(data as ProjectRow)
    set((state) => ({ allProjects: [project, ...state.allProjects] }))
    return project
  },

  setNoteProject: async (noteId, projectId) => {
    const prevNote = get().notes.find((n) => n.id === noteId)

    // 낙관적 갱신 — 고른 즉시 카드에 뜨고, 실패하면 해당 노트만 되돌린다 (BRU-114)
    set((state) => ({
      notes: state.notes.map((note) => (note.id === noteId ? { ...note, projectId } : note)),
    }))

    const { error } = await supabase
      .from('notes')
      .update({ project_id: projectId })
      .eq('id', noteId)

    if (error) {
      console.error('[projects] setNoteProject failed', error)
      set((state) => ({
        notes: prevNote ? restoreNoteFields(state.notes, prevNote) : state.notes,
      }))
      useToastStore.getState().showToast({
        message: projectId ? '프로젝트를 지정하지 못했습니다' : '프로젝트를 해제하지 못했습니다',
        variant: 'error',
      })
    }
  },

  setFilterProject: (projectId) => set({ filterProjectId: projectId }),
})
