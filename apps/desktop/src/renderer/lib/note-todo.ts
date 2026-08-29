// 할일 노트의 상태 전이 규칙 (BRU-175).
//
// 저장소·화면과 떼어 놓은 순수 함수다. 낙관적 갱신은 "화면을 먼저 바꾸고 나중에
// 서버에 알린다"는 뜻이라, 화면이 취할 다음 모습과 서버에 보낼 값이 **같은 규칙에서**
// 나와야 한다. 두 곳에 따로 적으면 실패 복구 때 어긋난다(BRU-114에서 겪은 것).

import type { Note, NoteType } from '@drop/shared'

/** 낙관적 갱신에 필요한 필드만 요구한다 — 테스트가 Note 전체를 만들지 않게 */
export interface TodoStateFields {
  type: NoteType
  completedAt: Date | null
}

/** DB 컬럼명 그대로의 갱신 페이로드 */
export interface TodoStatePatch {
  type: NoteType
  completed_at: string | null
}

/**
 * 타입을 바꾼 뒤의 상태.
 *
 * 일반 노트로 되돌리면 완료 시각도 함께 지운다. DB CHECK(notes_todo_state_consistent)가
 * 남은 완료 시각을 거부하므로, 지우지 않으면 이 갱신 자체가 실패한다. 예외를 던지는
 * 대신 "할일이 아니게 되면 완료도 아니다"로 흘려보낸다.
 */
export function withNoteType(note: TodoStateFields, type: NoteType): TodoStateFields {
  return {
    type,
    completedAt: type === 'todo' ? note.completedAt : null,
  }
}

/**
 * 완료를 뒤집은 뒤의 상태.
 *
 * 할일이 아닌 노트는 건드리지 않는다 — 조용히 타입까지 바꿔 주면 "완료했더니
 * 노트 종류가 변했다"가 된다. 체크박스는 할일에만 그리므로 여기 닿을 일이 없지만,
 * 단축키·MCP 등 다른 입구가 생겨도 규칙이 한 곳에 남아 있게 한다.
 */
export function toggleCompleted(note: TodoStateFields, now: Date): TodoStateFields {
  if (note.type !== 'todo') return note
  return { type: 'todo', completedAt: note.completedAt ? null : now }
}

/** 화면 상태를 그대로 DB 페이로드로 옮긴다 — 두 값이 갈라지지 않게 한 곳에서 만든다 */
export function toTodoStatePatch(fields: TodoStateFields): TodoStatePatch {
  return {
    type: fields.type,
    completed_at: fields.completedAt ? fields.completedAt.toISOString() : null,
  }
}

/** 낙관적 갱신 — 목록에서 그 노트만 새 상태로 갈아 끼운다 */
export function applyTodoState<T extends Note>(notes: T[], noteId: string, next: TodoStateFields): T[] {
  return notes.map((note) =>
    note.id === noteId ? { ...note, type: next.type, completedAt: next.completedAt } : note
  )
}
