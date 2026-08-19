// 태그 슬라이스 — 서버 왕복이 끼는 경로의 회귀 테스트 (BRU-81).
//
// 순수 전이(tag-mutations)는 따로 검증한다. 여기서 지키는 것은 그 전이를 "언제 무슨 id로"
// 서버에 흘려보내는가다. 낙관적 부착이 만든 임시 id가 서버로 새어 나가거나, 보관함·휴지통
// 노트의 해제가 아예 서버에 안 나가는 종류의 버그는 여기서만 잡힌다.

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
      select() {
        return api
      },
      order() {
        return api
      },
      single() {
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
        upsert: (payload: Record<string, unknown>) => builder(table, 'upsert', payload),
        update: (payload: Record<string, unknown>) => builder(table, 'update', payload),
        delete: () => builder(table, 'delete'),
        select: () => builder(table, 'select'),
      }
    },
  }

  return { calls, setHandler, supabase }
})

vi.mock('../../../lib/supabase', () => ({ supabase: h.supabase }))
vi.mock('../../auth', () => ({
  useAuthStore: { getState: () => ({ user: { id: 'user-1' } }) },
}))

import { createTagsSlice } from '../tags-slice'
import type { NotesState } from '../types'

interface TestNote {
  id: string
  tags: { id: string; name: string; createdAt: Date; lastUsedAt: Date | null }[]
}

interface Seed {
  notes?: TestNote[]
  archivedNotes?: TestNote[]
  trashedNotes?: TestNote[]
  allTags?: NotesState['allTags']
}

function makeStore(seed: Seed = {}) {
  return create<NotesState>()((...a) => {
    const slice = createTagsSlice(...a)
    return {
      notes: [],
      archivedNotes: [],
      trashedNotes: [],
      ...slice,
      ...seed,
    } as unknown as NotesState
  })
}

function tagRow(id: string, name: string) {
  return { id, name, created_at: '2026-01-01T00:00:00Z', last_used_at: '2026-01-01T00:00:00Z' }
}

function existingTag(id: string, name: string) {
  return { id, name, createdAt: new Date('2026-01-01'), lastUsedAt: new Date('2026-01-01') }
}

/** 이 호출에 임시 id가 실렸나 — payload든 필터든 */
/** 아직 답하지 않은 서버 응답 — 테스트가 원하는 시점에 풀어 준다 */
function deferred<T>() {
  let resolve!: (value: T) => void
  const promise = new Promise<T>((r) => (resolve = r))
  return { promise, resolve }
}

function carriesProvisionalId(call: RecordedCall): boolean {
  const values = [...Object.values(call.payload ?? {}), ...Object.values(call.filters)]
  return values.some((v) => typeof v === 'string' && v.startsWith('pending:'))
}

beforeEach(() => {
  h.calls.length = 0
  h.setHandler(async () => ({ data: null, error: null }))
  vi.spyOn(console, 'error').mockImplementation(() => {})
})

describe('addTagToNote — 낙관적 부착', () => {
  it('서버 왕복을 기다리지 않고 칩을 먼저 붙인다', async () => {
    const store = makeStore({ notes: [{ id: 'n1', tags: [] }] })
    const pending = deferred<{ data: unknown; error: unknown }>()
    h.setHandler(() => pending.promise)

    const inFlight = store.getState().addTagToNote('n1', 'foo')

    // 아직 서버는 한마디도 하지 않았는데 칩은 이미 붙어 있다
    expect(store.getState().notes[0].tags.map((t) => t.name)).toEqual(['foo'])

    pending.resolve({ data: tagRow('t1', 'foo'), error: null })
    await inFlight
  })

  it('서버가 준 진짜 id로 임시 id를 갈아 끼운다', async () => {
    const store = makeStore({ notes: [{ id: 'n1', tags: [] }] })
    h.setHandler(async (call) =>
      call.table === 'tags' ? { data: tagRow('real-1', 'foo'), error: null } : { error: null }
    )

    await store.getState().addTagToNote('n1', 'foo')

    expect(store.getState().notes[0].tags.map((t) => t.id)).toEqual(['real-1'])
    expect(store.getState().allTags.map((t) => t.id)).toEqual(['real-1'])
    const link = h.calls.find((c) => c.table === 'note_tags' && c.op === 'upsert')
    expect(link?.payload).toEqual({ note_id: 'n1', tag_id: 'real-1' })
  })

  it('태그 생성이 실패하면 칩과 태그 목록을 되돌린다', async () => {
    const store = makeStore({ notes: [{ id: 'n1', tags: [] }] })
    h.setHandler(async (call) =>
      call.table === 'tags' ? { data: null, error: new Error('boom') } : { error: null }
    )

    await store.getState().addTagToNote('n1', 'foo')

    expect(store.getState().notes[0].tags).toEqual([])
    expect(store.getState().allTags).toEqual([])
  })

  it('last_used_at 갱신이 실패해도 부착은 되돌리지 않는다', async () => {
    const tag = existingTag('t1', 'foo')
    const store = makeStore({ notes: [{ id: 'n1', tags: [] }], allTags: [tag] })
    h.setHandler(async (call) =>
      call.table === 'tags' && call.op === 'update'
        ? { error: new Error('last_used_at 실패') }
        : { error: null }
    )

    await store.getState().addTagToNote('n1', 'foo')

    expect(store.getState().notes[0].tags.map((t) => t.id)).toEqual(['t1'])
  })

  it('note_tags 연결만 실패하면 서버에 실재하는 태그는 목록에 남긴다', async () => {
    const store = makeStore({ notes: [{ id: 'n1', tags: [] }] })
    h.setHandler(async (call) =>
      call.table === 'tags'
        ? { data: tagRow('real-1', 'foo'), error: null }
        : { error: new Error('link 실패') }
    )

    await store.getState().addTagToNote('n1', 'foo')

    expect(store.getState().notes[0].tags).toEqual([])
    expect(store.getState().allTags.map((t) => t.id)).toEqual(['real-1'])
  })
})

// 🔴 A — 새 태그가 아직 서버 id를 못 받은 사이에 같은 이름을 다른 노트에 붙이면,
// 그 노트의 요청에 'pending:…'가 실려 uuid 파싱 에러로 죽고 칩이 조용히 사라졌다.
describe('addTagToNote — 서버 응답 전에 같은 이름을 다른 노트에 붙일 때', () => {
  it('임시 id를 서버로 보내지 않고 진짜 id를 기다린다', async () => {
    const store = makeStore({
      notes: [
        { id: 'n1', tags: [] },
        { id: 'n2', tags: [] },
      ],
    })

    const tagUpsert = deferred<{ data: unknown; error: unknown }>()
    h.setHandler((call) =>
      call.table === 'tags' && call.op === 'upsert'
        ? tagUpsert.promise
        : Promise.resolve({ error: null })
    )

    const first = store.getState().addTagToNote('n1', 'foo')
    const second = store.getState().addTagToNote('n2', 'foo')

    tagUpsert.resolve({ data: tagRow('real-1', 'foo'), error: null })
    await Promise.all([first, second])

    expect(h.calls.filter(carriesProvisionalId)).toEqual([])
    expect(store.getState().notes[1].tags.map((t) => t.id)).toEqual(['real-1'])
    const links = h.calls.filter((c) => c.table === 'note_tags' && c.op === 'upsert')
    expect(links.map((c) => c.payload)).toEqual(
      expect.arrayContaining([
        { note_id: 'n1', tag_id: 'real-1' },
        { note_id: 'n2', tag_id: 'real-1' },
      ])
    )
  })

  it('원 부착이 실패하면 뒤따르던 부착도 요청을 보내지 않고 되돌린다', async () => {
    const store = makeStore({
      notes: [
        { id: 'n1', tags: [] },
        { id: 'n2', tags: [] },
      ],
    })

    const tagUpsert = deferred<{ data: unknown; error: unknown }>()
    h.setHandler((call) =>
      call.table === 'tags' && call.op === 'upsert'
        ? tagUpsert.promise
        : Promise.resolve({ error: null })
    )

    const first = store.getState().addTagToNote('n1', 'foo')
    const second = store.getState().addTagToNote('n2', 'foo')

    tagUpsert.resolve({ data: null, error: new Error('boom') })
    await Promise.all([first, second])

    expect(h.calls.filter((c) => c.table === 'note_tags')).toEqual([])
    expect(store.getState().notes[0].tags).toEqual([])
    expect(store.getState().notes[1].tags).toEqual([])
    expect(store.getState().allTags).toEqual([])
  })
})

// 🔴 B — TagList의 × 버튼은 뷰 모드와 무관하게 렌더된다. 활성 배열만 보던 가드가
// 보관함·휴지통 노트의 해제를 통째로 삼켰다.
describe('removeTagFromNote — 보관함·휴지통 노트', () => {
  it('보관함 노트의 태그 해제도 서버에 나간다', async () => {
    const tag = existingTag('t1', 'foo')
    const store = makeStore({ archivedNotes: [{ id: 'a1', tags: [tag] }], allTags: [tag] })

    await store.getState().removeTagFromNote('a1', 't1')

    const del = h.calls.find((c) => c.table === 'note_tags' && c.op === 'delete')
    expect(del?.filters).toEqual({ note_id: 'a1', tag_id: 't1' })
    expect(store.getState().archivedNotes[0].tags).toEqual([])
  })

  it('휴지통 노트의 태그 해제도 서버에 나간다', async () => {
    const tag = existingTag('t1', 'foo')
    const store = makeStore({ trashedNotes: [{ id: 'x1', tags: [tag] }], allTags: [tag] })

    await store.getState().removeTagFromNote('x1', 't1')

    const del = h.calls.find((c) => c.table === 'note_tags' && c.op === 'delete')
    expect(del?.filters).toEqual({ note_id: 'x1', tag_id: 't1' })
    expect(store.getState().trashedNotes[0].tags).toEqual([])
  })

  it('삭제가 실패하면 칩을 되돌린다', async () => {
    const tag = existingTag('t1', 'foo')
    const store = makeStore({ archivedNotes: [{ id: 'a1', tags: [tag] }], allTags: [tag] })
    h.setHandler(async () => ({ error: new Error('delete 실패') }))

    await store.getState().removeTagFromNote('a1', 't1')

    expect(store.getState().archivedNotes[0].tags.map((t) => t.id)).toEqual(['t1'])
  })

  it('활성 노트 경로는 그대로 돈다', async () => {
    const tag = existingTag('t1', 'foo')
    const store = makeStore({ notes: [{ id: 'n1', tags: [tag] }], allTags: [tag] })

    await store.getState().removeTagFromNote('n1', 't1')

    expect(store.getState().notes[0].tags).toEqual([])
    const del = h.calls.find((c) => c.table === 'note_tags' && c.op === 'delete')
    expect(del?.filters).toEqual({ note_id: 'n1', tag_id: 't1' })
  })
})
