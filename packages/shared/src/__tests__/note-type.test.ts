import { describe, it, expect } from 'vitest'
import { noteRowToNote, isTodo, isCompleted, type NoteRow } from '../types'

/**
 * 노트 타입과 할일 완료 상태의 행 ↔ 앱 타입 변환 (BRU-175).
 *
 * DB는 `type`/`completed_at`(snake·문자열)로, 앱은 `type`/`completedAt`(Date)로 다룬다.
 * 그 사이에서 값이 사라지거나 뜻이 바뀌지 않는지를 여기서 못박는다.
 */

function row(overrides: Partial<NoteRow> = {}): NoteRow {
  return {
    id: 'n1',
    display_id: 1,
    content: '내용',
    parent_id: null,
    created_at: '2026-08-29T00:00:00.000Z',
    updated_at: '2026-08-29T00:00:00.000Z',
    source: 'desktop',
    is_deleted: false,
    user_id: 'u1',
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

describe('noteRowToNote — 타입과 완료 상태', () => {
  it('일반 노트는 type이 note이고 완료 시각이 없다', () => {
    const note = noteRowToNote(row())
    expect(note.type).toBe('note')
    expect(note.completedAt).toBeNull()
  })

  it('할일 노트의 type을 그대로 옮긴다', () => {
    expect(noteRowToNote(row({ type: 'todo' })).type).toBe('todo')
  })

  it('완료 시각을 Date로 옮긴다', () => {
    const note = noteRowToNote(
      row({ type: 'todo', completed_at: '2026-08-29T10:30:00.000Z' })
    )
    expect(note.completedAt).toEqual(new Date('2026-08-29T10:30:00.000Z'))
  })

  // 백필 이전에 만들어진 행이나, type을 고르지 않는 옛 클라이언트가 보낸 행이
  // 섞여 들어와도 화면이 깨지면 안 된다. DB 기본값과 같은 쪽으로 넘어뜨린다.
  it('type이 비어 있는 행은 일반 노트로 본다', () => {
    const legacy = { ...row(), type: undefined } as unknown as NoteRow
    expect(noteRowToNote(legacy).type).toBe('note')
  })
})

describe('isTodo — 할일인가', () => {
  it('type이 todo면 참', () => {
    expect(isTodo({ type: 'todo' })).toBe(true)
  })

  it('일반 노트면 거짓', () => {
    expect(isTodo({ type: 'note' })).toBe(false)
  })
})

describe('isCompleted — 끝난 할일인가', () => {
  it('완료 시각이 있으면 참', () => {
    expect(isCompleted({ type: 'todo', completedAt: new Date() })).toBe(true)
  })

  it('할일이지만 아직 안 끝났으면 거짓', () => {
    expect(isCompleted({ type: 'todo', completedAt: null })).toBe(false)
  })

  // DB CHECK(notes_todo_state_consistent)가 이 조합을 막지만, 앱 쪽 판정도
  // 타입을 함께 본다 — 제약이 한 겹 뚫려도 일반 노트에 취소선이 그어지지 않는다.
  it('일반 노트는 완료 시각이 있어도 거짓', () => {
    expect(isCompleted({ type: 'note', completedAt: new Date() })).toBe(false)
  })
})
