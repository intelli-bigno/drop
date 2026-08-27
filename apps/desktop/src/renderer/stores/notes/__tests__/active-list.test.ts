// 활성 목록(전체 리스트)의 관문 — BRU-108 회귀 테스트.
//
// `notes` 배열은 "삭제되지도 보관되지도 않은 노트"만 담기로 되어 있다. loadNotes()는
// 그 약속을 쿼리로 지키지만 realtime은 행이 그대로 들어온다 — 그래서 관문이 필요하고,
// 관문은 여기 하나뿐이어야 한다. 보관한 노트가 전체 목록에 다시 나타난 원인이 이것이다.

import { describe, expect, it } from 'vitest'
import type { Note, NoteRow } from '@drop/shared'
import { noteRowToNote } from '@drop/shared'
import { reconcileActiveList, restoreNoteFields, restoreNoteInList } from '../active-list'

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

const ids = (notes: Note[]) => notes.map((n) => n.id)

describe('reconcileActiveList — 들이지 않는 것', () => {
  it('보관된 노트는 목록에 없던 것이라도 들이지 않는다', () => {
    const next = reconcileActiveList([], row({ archived_at: '2026-08-25T01:00:00Z' }))

    expect(ids(next)).toEqual([])
  })

  it('삭제된 노트는 목록에 없던 것이라도 들이지 않는다', () => {
    const next = reconcileActiveList([], row({ deleted_at: '2026-08-25T01:00:00Z' }))

    expect(ids(next)).toEqual([])
  })

  it('보관되면 목록에 있던 노트도 뺀다', () => {
    const existing = [noteRowToNote(row({ id: 'n1' }))]

    const next = reconcileActiveList(
      existing,
      row({ id: 'n1', archived_at: '2026-08-25T01:00:00Z' })
    )

    expect(ids(next)).toEqual([])
  })

  it('삭제되면 목록에 있던 노트도 뺀다', () => {
    const existing = [noteRowToNote(row({ id: 'n1' }))]

    const next = reconcileActiveList(
      existing,
      row({ id: 'n1', deleted_at: '2026-08-25T01:00:00Z' })
    )

    expect(ids(next)).toEqual([])
  })
})

describe('reconcileActiveList — 들이는 것', () => {
  it('멀쩡한 새 노트는 맨 앞에 넣는다', () => {
    const existing = [noteRowToNote(row({ id: 'old' }))]

    const next = reconcileActiveList(existing, row({ id: 'new' }))

    expect(ids(next)).toEqual(['new', 'old'])
  })

  it('이미 있는 노트를 두 번 넣지 않는다 (로컬에서 만든 노트의 에코)', () => {
    const existing = [noteRowToNote(row({ id: 'n1' }))]

    const next = reconcileActiveList(existing, row({ id: 'n1' }))

    expect(ids(next)).toEqual(['n1'])
  })

  it('목록에 있는 노트는 자리를 지킨 채 내용만 갱신한다', () => {
    const existing = [noteRowToNote(row({ id: 'a' })), noteRowToNote(row({ id: 'b' }))]

    const next = reconcileActiveList(
      existing,
      row({ id: 'b', content: '고침', updated_at: '2026-08-25T02:00:00Z' })
    )

    expect(ids(next)).toEqual(['a', 'b'])
    expect(next[1].content).toBe('고침')
  })

  it('다른 기기에서 보관이 풀린 노트는 활성 목록으로 돌아온다', () => {
    // 이 앱에서 보관해 목록에서 빠진 노트를 다른 기기·MCP가 보관 해제하면 UPDATE만 온다.
    // 예전에는 map으로만 처리해 아무 일도 일어나지 않았고, 다음 loadNotes()까지 사라진 채였다.
    const next = reconcileActiveList([], row({ id: 'n1', archived_at: null }))

    expect(ids(next)).toEqual(['n1'])
  })
})

describe('restoreNoteInList — 실패 롤백 (BRU-114)', () => {
  it('빠진 노트를 피드 순서 제자리에 되넣는다', () => {
    const existing = [
      noteRowToNote(row({ id: 'today', created_at: '2026-08-25T00:00:00Z' })),
      noteRowToNote(row({ id: 'jul01', created_at: '2026-07-01T00:00:00Z' })),
    ]
    const missing = noteRowToNote(row({ id: 'aug10', created_at: '2026-08-10T00:00:00Z' }))

    expect(ids(restoreNoteInList(existing, missing))).toEqual(['today', 'aug10', 'jul01'])
  })

  it('이미 있는 노트는 두 번 넣지 않는다', () => {
    const existing = [noteRowToNote(row({ id: 'n1' }))]

    expect(ids(restoreNoteInList(existing, noteRowToNote(row({ id: 'n1' }))))).toEqual(['n1'])
  })

  it('보관된 노트는 활성 목록에 되넣지 않는다', () => {
    const archived = noteRowToNote(row({ id: 'n1', archived_at: '2026-08-25T01:00:00Z' }))

    expect(ids(restoreNoteInList([], archived))).toEqual([])
  })

  it('삭제된 노트는 활성 목록에 되넣지 않는다', () => {
    const deleted = noteRowToNote(row({ id: 'n1', deleted_at: '2026-08-25T01:00:00Z' }))

    expect(ids(restoreNoteInList([], deleted))).toEqual([])
  })
})

describe('restoreNoteFields — 실패 롤백 (BRU-114)', () => {
  it('목록에 있는 노트만 스냅샷으로 되돌린다', () => {
    const original = noteRowToNote(row({ id: 'n1', project_id: null }))
    const mutated = [{ ...original, projectId: 'p1' }, noteRowToNote(row({ id: 'n2' }))]

    const next = restoreNoteFields(mutated, original)

    expect(next[0].projectId).toBeNull()
    expect(ids(next)).toEqual(['n1', 'n2'])
  })

  it('그 사이 빠진 노트는 되넣지 않는다', () => {
    const original = noteRowToNote(row({ id: 'n1' }))
    const remaining = [noteRowToNote(row({ id: 'n2' }))]

    expect(ids(restoreNoteFields(remaining, original))).toEqual(['n2'])
  })

  it('다른 노트의 동시 변경은 유지한다', () => {
    const originalA = noteRowToNote(row({ id: 'a', project_id: null }))
    const current = [
      { ...originalA, projectId: 'p1' },
      noteRowToNote(row({ id: 'b', content: '동시 갱신' })),
    ]

    const next = restoreNoteFields(current, originalA)

    expect(next[0].projectId).toBeNull()
    expect(next[1].content).toBe('동시 갱신')
  })
})
