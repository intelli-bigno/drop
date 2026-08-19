import { describe, it, expect } from 'vitest'
import type { Tag } from '@drop/shared'
import {
  applyTagAttach,
  applyTagDetach,
  isProvisionalTagId,
  provisionalTagId,
  reconcileTagId,
  resolveTagForAttach,
  sortTagsByLastUsed,
} from '../tag-mutations'

const T0 = new Date('2026-08-01T00:00:00Z')
const NOW = new Date('2026-08-19T12:00:00Z')

const tag = (id: string, name: string, lastUsedAt: Date | null = null): Tag => ({
  id,
  name,
  createdAt: T0,
  lastUsedAt,
})

const note = (id: string, tags: Tag[] = []) => ({ id, tags })

describe('sortTagsByLastUsed', () => {
  it('최근에 쓴 태그가 앞에 온다', () => {
    const a = tag('a', 'a', new Date('2026-08-10T00:00:00Z'))
    const b = tag('b', 'b', new Date('2026-08-18T00:00:00Z'))
    expect(sortTagsByLastUsed([a, b]).map((t) => t.id)).toEqual(['b', 'a'])
  })

  it('한 번도 안 쓴 태그는 맨 뒤로 간다', () => {
    const a = tag('a', 'a', null)
    const b = tag('b', 'b', new Date('2026-08-10T00:00:00Z'))
    expect(sortTagsByLastUsed([a, b]).map((t) => t.id)).toEqual(['b', 'a'])
  })

  it('원본 배열을 건드리지 않는다', () => {
    const input = [tag('a', 'a', null), tag('b', 'b', NOW)]
    sortTagsByLastUsed(input)
    expect(input.map((t) => t.id)).toEqual(['a', 'b'])
  })
})

describe('provisionalTagId', () => {
  it('임시 id는 임시라고 알아볼 수 있다', () => {
    expect(isProvisionalTagId(provisionalTagId('seed'))).toBe(true)
  })

  it('서버가 준 uuid는 임시가 아니다', () => {
    expect(isProvisionalTagId('0d8bc0f2-6f3e-4c58-9c6e-2f2e4c8ab111')).toBe(false)
  })
})

describe('resolveTagForAttach', () => {
  it('빈 이름이면 아무것도 정하지 않는다', () => {
    expect(
      resolveTagForAttach({ allTags: [], tagName: '   ', now: NOW, provisionalId: 'p' })
    ).toBeNull()
  })

  it('이미 아는 이름이면 그 태그를 쓰고 사용 시각만 올린다', () => {
    const existing = tag('real-1', 'work', T0)
    const resolved = resolveTagForAttach({
      allTags: [existing],
      tagName: '  WORK ',
      now: NOW,
      provisionalId: 'p',
    })
    expect(resolved).toEqual({ tag: { ...existing, lastUsedAt: NOW }, isNew: false })
  })

  it('모르는 이름이면 임시 id로 새 태그를 만든다 — 서버 왕복 없이', () => {
    const resolved = resolveTagForAttach({
      allTags: [],
      tagName: 'Fresh',
      now: NOW,
      provisionalId: 'pending:1',
    })
    expect(resolved).toEqual({
      tag: { id: 'pending:1', name: 'fresh', createdAt: NOW, lastUsedAt: NOW },
      isNew: true,
    })
  })
})

describe('applyTagAttach', () => {
  it('왕복을 기다리지 않고 노트에 태그를 붙인다', () => {
    const t = tag('t1', 'work', NOW)
    const next = applyTagAttach({
      notes: [note('n1'), note('n2')],
      allTags: [],
      noteId: 'n1',
      tag: t,
    })
    expect(next.notes[0].tags).toEqual([t])
    expect(next.notes[1].tags).toEqual([])
    expect(next.allTags).toEqual([t])
  })

  it('이미 붙어 있으면 중복으로 붙이지 않는다', () => {
    const t = tag('t1', 'work', NOW)
    const next = applyTagAttach({ notes: [note('n1', [t])], allTags: [t], noteId: 'n1', tag: t })
    expect(next.notes[0].tags).toEqual([t])
    expect(next.allTags).toEqual([t])
  })

  it('건드리지 않은 노트는 참조까지 그대로 둔다 — 불필요한 리렌더를 막는다', () => {
    const untouched = note('n2')
    const next = applyTagAttach({
      notes: [note('n1'), untouched],
      allTags: [],
      noteId: 'n1',
      tag: tag('t1', 'work', NOW),
    })
    expect(next.notes[1]).toBe(untouched)
  })

  it('아는 태그면 allTags 안의 항목을 갱신하고 최근 순으로 올린다', () => {
    const older = tag('t1', 'work', T0)
    const other = tag('t2', 'idea', new Date('2026-08-15T00:00:00Z'))
    const bumped = { ...older, lastUsedAt: NOW }
    const next = applyTagAttach({
      notes: [note('n1')],
      allTags: [other, older],
      noteId: 'n1',
      tag: bumped,
    })
    expect(next.allTags.map((t) => t.id)).toEqual(['t1', 't2'])
    expect(next.allTags[0]).toEqual(bumped)
  })
})

describe('applyTagDetach', () => {
  it('노트에서 태그를 뗀다', () => {
    const t = tag('t1', 'work', NOW)
    const next = applyTagDetach({
      notes: [note('n1', [t])],
      allTags: [t],
      noteId: 'n1',
      tagId: 't1',
    })
    expect(next.notes[0].tags).toEqual([])
    expect(next.allTags).toEqual([t])
  })

  it('붙일 때 새로 만든 태그였다면 롤백에서 목록에서도 지운다', () => {
    const t = tag('pending:1', 'fresh', NOW)
    const next = applyTagDetach({
      notes: [note('n1', [t])],
      allTags: [t],
      noteId: 'n1',
      tagId: 'pending:1',
      dropFromAllTags: true,
    })
    expect(next.notes[0].tags).toEqual([])
    expect(next.allTags).toEqual([])
  })

  it('건드리지 않은 노트는 참조까지 그대로 둔다', () => {
    const t = tag('t1', 'work', NOW)
    const untouched = note('n2', [t])
    const next = applyTagDetach({
      notes: [note('n1', [t]), untouched],
      allTags: [t],
      noteId: 'n1',
      tagId: 't1',
    })
    expect(next.notes[1]).toBe(untouched)
  })
})

describe('reconcileTagId', () => {
  it('임시 id를 서버가 준 진짜 태그로 바꿔 끼운다', () => {
    const provisional = tag('pending:1', 'fresh', NOW)
    const real = tag('real-9', 'fresh', NOW)
    const next = reconcileTagId({
      notes: [note('n1', [provisional]), note('n2')],
      allTags: [provisional],
      provisionalId: 'pending:1',
      tag: real,
    })
    expect(next.notes[0].tags).toEqual([real])
    expect(next.allTags).toEqual([real])
  })

  it('이미 진짜 id면 아무것도 바꾸지 않는다', () => {
    const real = tag('real-9', 'fresh', NOW)
    const notes = [note('n1', [real])]
    const allTags = [real]
    const next = reconcileTagId({ notes, allTags, provisionalId: 'real-9', tag: real })
    expect(next.notes).toBe(notes)
    expect(next.allTags).toBe(allTags)
  })
})
