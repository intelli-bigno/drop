// realtime 구독이 활성 목록에 무엇을 들이는가 — BRU-108 회귀 테스트.
//
// 관문 자체(reconcileActiveList)는 active-list.test.ts에서 지킨다. 여기서 지키는 것은
// 구독 핸들러가 그 관문을 실제로 지나가는가다. 페이로드를 손으로 흘려 넣어 확인한다.

import { beforeEach, describe, expect, it, vi } from 'vitest'
import { create } from 'zustand'
import type { NoteRow } from '@drop/shared'

type Handler = (payload: {
  eventType: 'INSERT' | 'UPDATE' | 'DELETE'
  new?: unknown
  old?: unknown
}) => void

const h = vi.hoisted(() => {
  const handlers: Handler[] = []
  const channel = {
    on(_event: string, _filter: unknown, handler: Handler) {
      handlers.push(handler)
      return channel
    },
    subscribe() {
      return channel
    },
  }
  const supabase = {
    channel: () => channel,
    removeChannel: vi.fn(),
    from: () => {
      throw new Error('이 테스트는 네트워크를 타지 않는다')
    },
  }
  return { handlers, supabase }
})

vi.mock('../../../lib/supabase', () => ({ supabase: h.supabase }))
vi.mock('../../auth', () => ({
  useAuthStore: { getState: () => ({ user: { id: 'user-1' } }) },
}))
vi.mock('../../toast', () => ({
  useToastStore: { getState: () => ({ showToast: vi.fn() }) },
}))

import { createNotesSlice } from '../notes-slice'
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
    ...overrides,
  }
}

function makeStore() {
  return create<NotesState>()((...a) => ({ ...createNotesSlice(...a) }) as unknown as NotesState)
}

beforeEach(() => {
  h.handlers.length = 0
})

describe('subscribeToChanges', () => {
  it('보관된 노트가 INSERT로 들어와도 전체 목록에 붙이지 않는다', () => {
    const store = makeStore()
    store.getState().subscribeToChanges()

    h.handlers[0]({
      eventType: 'INSERT',
      new: row({ id: 'archived-1', archived_at: '2026-08-25T01:00:00Z' }),
    })

    expect(store.getState().notes).toEqual([])
  })

  it('멀쩡한 노트는 INSERT로 붙인다', () => {
    const store = makeStore()
    store.getState().subscribeToChanges()

    h.handlers[0]({ eventType: 'INSERT', new: row({ id: 'fresh' }) })

    expect(store.getState().notes.map((n) => n.id)).toEqual(['fresh'])
  })
})
