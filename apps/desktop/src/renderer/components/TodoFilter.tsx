import { useMemo } from 'react'
import { useNotesStore } from '../stores/notes'
import { countOpenTodos } from '../lib/note-filters'
import { Icon } from './Icon'

/**
 * 할일 필터 (BRU-175) — 세 상태를 한 버튼으로 돈다.
 *
 *   전체 → 할일(끝난 것 포함) → 남은 할일만 → 전체
 *
 * 왜 순환인가: 이 세 값은 서로 배타적이라 체크박스 두 개보다 버튼 하나가 맞다.
 * 긴급도 점이 이미 같은 방식으로 도므로 조작법이 하나 더 늘지 않는다.
 *
 * 숫자는 **남은 것**만 센다. 목록은 "무엇을 했나"까지 보여 주지만 숫자는
 * "얼마나 남았나"에 답해야 한다 — 두 질문이 다르므로 답도 다르다.
 */
const LABELS = {
  todo: '할일',
  open: '남은 할일',
} as const

export function TodoFilter() {
  const notes = useNotesStore((s) => s.notes)
  const todoFilter = useNotesStore((s) => s.todoFilter)
  const setTodoFilter = useNotesStore((s) => s.setTodoFilter)

  const count = useMemo(() => countOpenTodos(notes), [notes])

  const next = todoFilter === null ? 'todo' : todoFilter === 'todo' ? 'open' : null
  const title =
    todoFilter === null
      ? '할일만 보기'
      : todoFilter === 'todo'
        ? '아직 안 끝난 할일만 보기'
        : '할일 필터 해제'

  return (
    <button
      className={`todo-filter-btn ${todoFilter ? 'active' : ''}`}
      onClick={() => setTodoFilter(next)}
      title={title}
      aria-pressed={todoFilter !== null}
    >
      <span className="todo-filter-icon">
        <Icon name="list-todo" size={13} />
      </span>
      <span className="todo-filter-label">{todoFilter ? LABELS[todoFilter] : '할일'}</span>
      <span className="todo-filter-count">{count}</span>
    </button>
  )
}
