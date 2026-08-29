// 활성 목록의 두 경쟁 상태 — BRU-114 회귀 테스트.
//
// BRU-108이 닫은 것은 realtime INSERT 관문 하나뿐이다. 아래 둘은 다른 경로로
// 같은 증상(사라져야 할 노트가 목록에 남음 / 남아야 할 노트가 사라짐)을 만든다.
//
// ① loadNotes()에 요청 순번이 없으면, 보관 커밋 전에 출발한 쿼리가 후에 응답해
//    보관된 노트를 다시 얹는다. 그 시점 DB 행의 archived_at은 아직 null이라
//    관문 검사를 정당하게 통과한다.
// ② 실패 롤백이 `set({ notes: prevNotes })`로 배열을 통째 되돌리면, 그 사이
//    realtime·다른 낙관적 갱신이 통째로 사라진다.

import { beforeEach, describe, expect, it, vi } from 'vitest'
import { create } from 'zustand'
import type { Note, NoteRow } from '@drop/shared'
import { noteRowToNote } from '@drop/shared'

type Result = { data?: unknown; error?: unknown }

const h = vi.hoisted(() => {
  const queues: Record<string, Array<() => Promise<Result>>> = {}

  function take(table: string): Promise<Result> {
    const q = queues[table]
    if (q && q.length > 0) return q.shift()!()
    return Promise.resolve({ data: [], error: null })
  }

  function enqueue(table: string, promise: Promise<Result>) {
    queues[table] ??= []
    queues[table].push(() => promise)
  }

  function builder(table: string) {
    const api = {
      select() {
        return api
      },
      update() {
        return api
      },
      insert() {
        return api
      },
      is() {
        return api
      },
      in() {
        return api
      },
      eq() {
        return api
      },
      not() {
        return api
      },
      order() {
        return api
      },
      single() {
        return api
      },
      then(onFulfilled: unknown, onRejected: unknown) {
        return take(table).then(onFulfilled as never, onRejected as never)
      },
    }
    return api
  }

  const showToast = vi.fn()
  const supabase = {
    from: (table: string) => builder(table),
  }

  return { queues, enqueue, showToast, supabase }
})

vi.mock('../../../lib/supabase', () => ({ supabase: h.supabase }))
vi.mock('../../auth', () => ({
  useAuthStore: { getState: () => ({ user: { id: 'user-1' } }) },
}))
vi.mock('../../toast', () => ({
  useToastStore: { getState: () => ({ showToast: h.showToast }) },
}))

import { createNotesSlice } from '../notes-slice'
import { createTrashSlice } from '../trash-slice'
import { createProjectsSlice } from '../projects-slice'
import { createExportSlice } from '../export-slice'
import type { NotesState } from '../types'

function row(overrides: Partial<NoteRow> = {}): NoteRow {
  return {
    id: 'n1',
    display_id: 1,
    content: '내용',
    parent_id: null,
    created_at: '2026-08-25T00:00:00Z',
    updated_at: '2026-08-25T00:00:00Z',
    source: 'desktop',
    is_deleted: false,
    user_id: 'user-1',
    has_link: false,
    has_media: false,
    has_files: false,
    is_locked: false,
    deleted_at: null,
    archived_at: null,
    priority: 0,
    is_pinned: false,
    pinned_at: null,
    linear_issue_url: null,
    linear_issue_key: null,
    linear_exported_at: null,
    project_id: null,
    type: 'note',
    completed_at: null,
    ...overrides,
  }
}

function note(overrides: Partial<NoteRow> = {}): Note {
  return noteRowToNote(row(overrides))
}

const ids = (notes: Note[]) => notes.map((n) => n.id)

function deferred<T>() {
  let resolve!: (value: T) => void
  const promise = new Promise<T>((r) => {
    resolve = r
  })
  return { promise, resolve }
}

function makeStore(seed: Partial<NotesState> = {}) {
  return create<NotesState>()((...a) => ({
    ...createNotesSlice(...a),
    ...createTrashSlice(...a),
    ...createProjectsSlice(...a),
    ...createExportSlice(...a),
    loadCommentCounts: vi.fn().mockResolvedValue(undefined),
    ...seed,
  }) as unknown as NotesState)
}

beforeEach(() => {
  for (const key of Object.keys(h.queues)) delete h.queues[key]
  h.showToast.mockReset()
  vi.spyOn(console, 'error').mockImplementation(() => {})
})

describe('loadNotes — 최신 응답이 이긴다 (BRU-114 ①)', () => {
  it('먼저 출발한 쿼리가 나중에 도착해도 목록을 덮지 않는다', async () => {
    // 보관 커밋 전에 출발한 쿼리(first)는 아직 archived_at이 null인 행을 싣고,
    // 후에 출발한 쿼리(second)는 그 행을 빼서 온다. 늦은 first가 이기면
    // 방금 보관한 노트가 전체 목록에 다시 보인다.
    const store = makeStore()
    const first = deferred<Result>()
    const second = deferred<Result>()
    h.enqueue('notes', first.promise)
    h.enqueue('notes', second.promise)

    const older = store.getState().loadNotes()
    const newer = store.getState().loadNotes()

    second.resolve({ data: [row({ id: 'b' })], error: null })
    await newer
    expect(ids(store.getState().notes)).toEqual(['b'])

    first.resolve({
      data: [row({ id: 'a' }), row({ id: 'b' })],
      error: null,
    })
    await older

    expect(ids(store.getState().notes)).toEqual(['b'])
  })

  it('늦은 응답이 도착하는 동안에도 앞선 응답으로 목록을 갈아끼우지 않는다', async () => {
    const store = makeStore()
    const first = deferred<Result>()
    const second = deferred<Result>()
    h.enqueue('notes', first.promise)
    h.enqueue('notes', second.promise)

    const older = store.getState().loadNotes()
    const newer = store.getState().loadNotes()

    first.resolve({
      data: [row({ id: 'a' }), row({ id: 'b' })],
      error: null,
    })
    await older
    expect(ids(store.getState().notes)).toEqual([])
    expect(store.getState().isLoading).toBe(true)

    second.resolve({ data: [row({ id: 'b' })], error: null })
    await newer

    expect(ids(store.getState().notes)).toEqual(['b'])
    expect(store.getState().isLoading).toBe(false)
  })
})

describe('실패 롤백 — 해당 노트만 되돌린다 (BRU-114 ②)', () => {
  it('archiveNote 실패가 그 사이 빠진 다른 노트를 되살리지 않는다', async () => {
    const a = note({ id: 'a', created_at: '2026-08-25T00:00:00Z' })
    const b = note({ id: 'b', created_at: '2026-08-24T00:00:00Z' })
    const c = note({ id: 'c', created_at: '2026-08-23T00:00:00Z' })
    const store = makeStore({ notes: [a, b, c] })

    const pending = deferred<Result>()
    h.enqueue('notes', pending.promise)
    const inflight = store.getState().archiveNote('a')
    expect(ids(store.getState().notes)).toEqual(['b', 'c'])

    store.setState({ notes: store.getState().notes.filter((n) => n.id !== 'c') })
    pending.resolve({ error: new Error('보관 실패') })
    await inflight

    expect(ids(store.getState().notes)).toEqual(['a', 'b'])
  })

  it('deleteNote 실패가 그 사이 빠진 다른 노트를 되살리지 않는다', async () => {
    const a = note({ id: 'a' })
    const b = note({ id: 'b' })
    const c = note({ id: 'c' })
    const store = makeStore({ notes: [a, b, c], archivedNotes: [] })

    const pending = deferred<Result>()
    h.enqueue('notes', pending.promise)
    const inflight = store.getState().deleteNote('a')
    expect(ids(store.getState().notes)).toEqual(['b', 'c'])

    store.setState({ notes: store.getState().notes.filter((n) => n.id !== 'c') })
    pending.resolve({ error: new Error('삭제 실패') })
    await inflight

    expect(ids(store.getState().notes)).toEqual(['a', 'b'])
  })

  it('deleteNote 실패가 보관함에서 그 사이 빠진 다른 노트를 되살리지 않는다', async () => {
    const a = note({ id: 'a', archived_at: '2026-08-25T01:00:00Z' })
    const c = note({ id: 'c', archived_at: '2026-08-24T01:00:00Z' })
    const store = makeStore({ notes: [], archivedNotes: [a, c] })

    const pending = deferred<Result>()
    h.enqueue('notes', pending.promise)
    const inflight = store.getState().deleteNote('a')
    expect(ids(store.getState().archivedNotes)).toEqual(['c'])

    store.setState({ archivedNotes: [] })
    pending.resolve({ error: new Error('삭제 실패') })
    await inflight

    expect(ids(store.getState().archivedNotes)).toEqual(['a'])
  })

  it('setNoteProject 실패가 그 사이 들어온 노트를 지우지 않는다', async () => {
    const a = note({ id: 'a', project_id: null })
    const b = note({ id: 'b' })
    const store = makeStore({ notes: [a, b] })

    const pending = deferred<Result>()
    h.enqueue('notes', pending.promise)
    const inflight = store.getState().setNoteProject('a', 'p1')
    expect(store.getState().notes[0].projectId).toBe('p1')

    store.setState({ notes: [...store.getState().notes, note({ id: 'c' })] })
    pending.resolve({ error: new Error('프로젝트 실패') })
    await inflight

    expect(ids(store.getState().notes)).toEqual(['a', 'b', 'c'])
    expect(store.getState().notes[0].projectId).toBeNull()
  })

  it('clearNoteExport 실패가 그 사이 들어온 노트를 지우지 않는다', async () => {
    const a = note({
      id: 'a',
      linear_issue_url: 'https://linear.app/x',
      linear_issue_key: 'BRU-1',
      linear_exported_at: '2026-08-25T01:00:00Z',
    })
    const store = makeStore({ notes: [a] })

    const pending = deferred<Result>()
    h.enqueue('notes', pending.promise)
    const inflight = store.getState().clearNoteExport('a')
    expect(store.getState().notes[0].linearIssueUrl).toBeNull()

    store.setState({ notes: [...store.getState().notes, note({ id: 'b' })] })
    pending.resolve({ error: new Error('반출 실패') })
    await inflight

    expect(ids(store.getState().notes)).toEqual(['a', 'b'])
    expect(store.getState().notes[0].linearIssueUrl).toBe('https://linear.app/x')
  })
})
