import { describe, it, expect } from 'vitest'
import {
  withNoteType,
  toggleCompleted,
  toTodoStatePatch,
  applyTodoState,
  type TodoStateFields,
} from '../note-todo'

const NOW = new Date('2026-08-29T10:30:00.000Z')

function fields(overrides: Partial<TodoStateFields> = {}): TodoStateFields {
  return { type: 'note', completedAt: null, ...overrides }
}

describe('withNoteType — 타입 전환', () => {
  it('일반 노트를 할일로 바꾼다', () => {
    expect(withNoteType(fields(), 'todo')).toEqual({ type: 'todo', completedAt: null })
  })

  it('할일을 일반 노트로 되돌린다', () => {
    expect(withNoteType(fields({ type: 'todo' }), 'note')).toEqual({
      type: 'note',
      completedAt: null,
    })
  })

  // DB CHECK(notes_todo_state_consistent)가 완료 시각이 남은 일반 노트를 거부한다.
  // 여기서 안 지우면 갱신 자체가 실패한다.
  it('되돌릴 때 완료 시각을 함께 지운다', () => {
    const done = fields({ type: 'todo', completedAt: NOW })
    expect(withNoteType(done, 'note').completedAt).toBeNull()
  })

  it('할일로 유지하면 완료 시각은 보존된다', () => {
    const done = fields({ type: 'todo', completedAt: NOW })
    expect(withNoteType(done, 'todo').completedAt).toEqual(NOW)
  })
})

describe('toggleCompleted — 완료 뒤집기', () => {
  it('미완료 할일에 완료 시각을 찍는다', () => {
    expect(toggleCompleted(fields({ type: 'todo' }), NOW)).toEqual({
      type: 'todo',
      completedAt: NOW,
    })
  })

  it('완료된 할일을 미완료로 되돌린다', () => {
    const done = fields({ type: 'todo', completedAt: NOW })
    expect(toggleCompleted(done, NOW).completedAt).toBeNull()
  })

  // 조용히 타입까지 바꿔 주면 "완료했더니 노트 종류가 변했다"가 된다
  it('일반 노트는 건드리지 않는다', () => {
    const plain = fields()
    expect(toggleCompleted(plain, NOW)).toBe(plain)
  })
})

describe('toTodoStatePatch — DB 페이로드', () => {
  it('완료 시각을 ISO 문자열로 옮긴다', () => {
    expect(toTodoStatePatch(fields({ type: 'todo', completedAt: NOW }))).toEqual({
      type: 'todo',
      completed_at: '2026-08-29T10:30:00.000Z',
    })
  })

  it('미완료는 null로 보낸다', () => {
    expect(toTodoStatePatch(fields({ type: 'todo' }))).toEqual({
      type: 'todo',
      completed_at: null,
    })
  })
})

describe('applyTodoState — 낙관적 갱신', () => {
  const notes = [
    { id: 'a', type: 'note' as const, completedAt: null },
    { id: 'b', type: 'todo' as const, completedAt: null },
  ]

  it('대상 노트만 갈아 끼운다', () => {
    const next = applyTodoState(notes as never, 'b', { type: 'todo', completedAt: NOW })
    expect(next[0]).toEqual(notes[0])
    expect(next[1]).toMatchObject({ id: 'b', type: 'todo', completedAt: NOW })
  })

  it('없는 id면 목록이 그대로다', () => {
    const next = applyTodoState(notes as never, 'zzz', { type: 'todo', completedAt: NOW })
    expect(next).toEqual(notes)
  })
})
