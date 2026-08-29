// BRU-125 회귀 테스트 — BRU-108이 관문을 하나로 모으면서 함께 버린 두 가지 방어.
//
// 관문을 하나로 둔 판단 자체는 옳다(그게 BRU-108이 닫은 구멍이다). 다만 INSERT·UPDATE
// 갈래가 각자 갖고 있던 규칙까지 사라졌다 — 넣을 자리를 찾는 일과, 뒤늦게 도착한
// 행이 최신 상태를 덮지 않게 막는 일이다.

import { describe, expect, it } from 'vitest'
import type { Note, NoteRow } from '@drop/shared'
import { noteRowToNote } from '@drop/shared'
import { reconcileActiveList } from '../active-list'

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

const ids = (notes: Note[]) => notes.map((n) => n.id)

describe('reconcileActiveList — 들일 자리 (BRU-125 ①)', () => {
  it('보관이 풀려 돌아온 옛 노트를 맨 앞이 아니라 날짜 순 제자리에 넣는다', () => {
    // 배열은 loadNotes() 정렬(created_at DESC)을 유지한다. 맨 앞에 꽂으면
    // NoteFeed의 날짜 그룹핑이 직전 그룹과만 병합하므로 같은 날짜 헤더가 두 번 뜬다.
    const existing = [
      noteRowToNote(row({ id: 'today', created_at: '2026-08-25T00:00:00Z' })),
      noteRowToNote(row({ id: 'aug10', created_at: '2026-08-10T00:00:00Z' })),
      noteRowToNote(row({ id: 'jul01', created_at: '2026-07-01T00:00:00Z' })),
    ]

    const next = reconcileActiveList(
      existing,
      row({ id: 'aug01', created_at: '2026-08-01T00:00:00Z', archived_at: null })
    )

    expect(ids(next)).toEqual(['today', 'aug10', 'aug01', 'jul01'])
  })

  it('고정된 노트는 고정되지 않은 최신 노트보다 앞에 넣는다', () => {
    const existing = [noteRowToNote(row({ id: 'today', created_at: '2026-08-25T00:00:00Z' }))]

    const next = reconcileActiveList(
      existing,
      row({
        id: 'pinned-old',
        created_at: '2026-01-01T00:00:00Z',
        is_pinned: true,
        pinned_at: '2026-08-20T00:00:00Z',
      })
    )

    expect(ids(next)).toEqual(['pinned-old', 'today'])
  })

  it('가장 오래된 노트보다 더 오래된 행은 맨 뒤에 붙인다', () => {
    const existing = [noteRowToNote(row({ id: 'aug10', created_at: '2026-08-10T00:00:00Z' }))]

    const next = reconcileActiveList(
      existing,
      row({ id: 'jan01', created_at: '2026-01-01T00:00:00Z' })
    )

    expect(ids(next)).toEqual(['aug10', 'jan01'])
  })
})

describe('reconcileActiveList — 뒤늦은 에코 (BRU-125 ②)', () => {
  it('저장된 것보다 오래된 행은 내용을 덮지 않는다', () => {
    // `n`이 빈 노트를 낙관적으로 넣고 → 타이핑으로 updateNote()가 먼저 도착하고 →
    // 그 뒤 INSERT 에코가 content:'' 를 싣고 온다. 방금 친 글이 사라지면 안 된다.
    const typed = [
      noteRowToNote(row({ id: 'n1', content: '방금 친 글', updated_at: '2026-08-25T00:00:05Z' })),
    ]

    const next = reconcileActiveList(
      typed,
      row({ id: 'n1', content: '', updated_at: '2026-08-25T00:00:00Z' })
    )

    expect(next[0].content).toBe('방금 친 글')
  })

  it('저장된 것과 같은 시각의 행은 적용한다 (updated_at을 안 올리는 갱신도 있다)', () => {
    const existing = [
      noteRowToNote(row({ id: 'n1', is_pinned: false, updated_at: '2026-08-25T00:00:00Z' })),
    ]

    const next = reconcileActiveList(
      existing,
      row({
        id: 'n1',
        is_pinned: true,
        pinned_at: '2026-08-25T00:00:00Z',
        updated_at: '2026-08-25T00:00:00Z',
      })
    )

    expect(next[0].isPinned).toBe(true)
  })

  it('뒤늦은 행이라도 보관·삭제 상태는 반영한다 — 목록에서 빼는 일은 늦어도 해야 한다', () => {
    const existing = [noteRowToNote(row({ id: 'n1', updated_at: '2026-08-25T00:00:05Z' }))]

    const next = reconcileActiveList(
      existing,
      row({ id: 'n1', archived_at: '2026-08-25T00:00:01Z', updated_at: '2026-08-25T00:00:00Z' })
    )

    expect(ids(next)).toEqual([])
  })
})
