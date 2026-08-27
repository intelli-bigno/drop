// BRU-115 Rule B — 휴지통에서 나오면 항상 활성이다.
//
// 보관된 노트를 휴지통으로 보낼 때 archived_at을 남기면 복원이 보관함으로
// 돌아간다. iOS는 이미 지웠고 데스크톱만 남기고 있어서 플랫폼마다 결과가 갈렸다.

import { beforeEach, describe, expect, it, vi } from 'vitest'
import { create } from 'zustand'

interface RecordedCall {
  table: string
  op: string
  payload?: Record<string, unknown>
  filters: Record<string, unknown>
}

const h = vi.hoisted(() => {
  const calls: RecordedCall[] = []
  let handler: (call: RecordedCall) => Promise<{ data?: unknown; error?: unknown }> = async () => ({
    data: null,
    error: null,
  })

  const setHandler = (next: typeof handler) => {
    handler = next
  }

  function builder(table: string, op: string, payload?: Record<string, unknown>) {
    const call: RecordedCall = { table, op, payload, filters: {} }
    calls.push(call)
    const api = {
      eq(column: string, value: unknown) {
        call.filters[column] = value
        return api
      },
      then(onFulfilled: unknown, onRejected: unknown) {
        return handler(call).then(onFulfilled as never, onRejected as never)
      },
    }
    return api
  }

  const supabase = {
    from(table: string) {
      return {
        update: (payload: Record<string, unknown>) => builder(table, 'update', payload),
      }
    },
  }

  const showToast = vi.fn()

  return { calls, setHandler, supabase, showToast }
})

vi.mock('../../../lib/supabase', () => ({ supabase: h.supabase }))
vi.mock('../../toast', () => ({
  useToastStore: { getState: () => ({ showToast: h.showToast }) },
}))

import { createNotesSlice } from '../notes-slice'
import { createTrashSlice } from '../trash-slice'
import type { NotesState } from '../types'

function makeStore(seed: Partial<NotesState> = {}) {
  return create<NotesState>()((...a) => {
    const notes = createNotesSlice(...a)
    const trash = createTrashSlice(...a)
    return {
      ...notes,
      ...trash,
      loadNotes: async () => {},
      loadArchived: async () => {},
      ...seed,
    } as unknown as NotesState
  })
}

beforeEach(() => {
  h.calls.length = 0
  h.setHandler(async () => ({ data: null, error: null }))
  h.showToast.mockReset()
  vi.spyOn(console, 'error').mockImplementation(() => {})
})

describe('deleteNote — Rule B', () => {
  it('휴지통으로 보낼 때 archived_at을 비운다', async () => {
    const store = makeStore({
      notes: [{ id: 'n1' }] as NotesState['notes'],
      archivedNotes: [{ id: 'n1' }] as NotesState['archivedNotes'],
    })

    await store.getState().deleteNote('n1')

    const update = h.calls.find((c) => c.table === 'notes' && c.op === 'update')
    expect(update?.filters).toEqual({ id: 'n1' })
    expect(update?.payload).toMatchObject({
      is_deleted: true,
      archived_at: null,
    })
    expect(typeof update?.payload?.deleted_at).toBe('string')
    expect(store.getState().notes.map((n) => n.id)).toEqual([])
    expect(store.getState().archivedNotes.map((n) => n.id)).toEqual([])
  })
})

describe('restoreNote — Rule B', () => {
  it('복원해도 archived_at을 다시 살리지 않는다', async () => {
    const store = makeStore({
      trashedNotes: [{ id: 'n1' }] as NotesState['trashedNotes'],
    })

    await store.getState().restoreNote('n1')

    const update = h.calls.find((c) => c.table === 'notes' && c.op === 'update')
    expect(update?.filters).toEqual({ id: 'n1' })
    expect(update?.payload).toEqual({
      deleted_at: null,
      is_deleted: false,
      archived_at: null,
    })
    expect(store.getState().trashedNotes.map((n) => n.id)).toEqual([])
  })
})
