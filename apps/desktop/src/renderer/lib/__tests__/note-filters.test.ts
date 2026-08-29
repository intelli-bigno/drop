import { describe, it, expect } from 'vitest'
import {
  applyNoteFilters,
  countInboxNotes,
  countOpenTodos,
  isExportedNote,
  isUntaggedNote,
  UNASSIGNED_PROJECT_ID,
  type FilterableNote,
  type NoteFilterOptions,
} from '../note-filters'

type TestNote = FilterableNote

function note(id: string, overrides: Partial<TestNote> = {}): TestNote {
  return {
    id,
    parentId: null,
    tags: [],
    hasLink: false,
    hasMedia: false,
    hasFiles: false,
    linearIssueUrl: null,
    ...overrides,
  }
}

/** Linear로 반출된 노트 (BRU-45) */
const exported = (id: string, overrides: Partial<TestNote> = {}) =>
  note(id, { linearIssueUrl: 'https://linear.app/intellieffect/issue/BRU-96/x', ...overrides })

const ids = (notes: TestNote[]) => notes.map((n) => n.id)

describe('applyNoteFilters', () => {
  it('필터가 없으면 원래 목록을 순서 그대로 돌려준다', () => {
    const notes = [note('a'), note('b'), note('c')]

    const result = applyNoteFilters(notes, { filterTag: null, categoryFilter: null })

    expect(ids(result)).toEqual(['a', 'b', 'c'])
  })

  it("categoryFilter가 'all'이면 아무것도 걸러내지 않는다", () => {
    const notes = [note('a'), note('b', { hasLink: true })]

    const result = applyNoteFilters(notes, { filterTag: null, categoryFilter: 'all' })

    expect(ids(result)).toEqual(['a', 'b'])
  })

  it('filterTag가 있으면 그 태그가 붙은 노트만 남긴다', () => {
    const notes = [
      note('a', { tags: [{ name: 'work' }] }),
      note('b', { tags: [{ name: 'home' }] }),
      note('c'),
    ]

    const result = applyNoteFilters(notes, { filterTag: 'work', categoryFilter: null })

    expect(ids(result)).toEqual(['a'])
  })

  it.each([
    ['link' as const, 'hasLink' as const],
    ['media' as const, 'hasMedia' as const],
    ['files' as const, 'hasFiles' as const],
  ])('categoryFilter %s는 %s인 노트만 남긴다', (categoryFilter, flag) => {
    const notes = [note('yes', { [flag]: true }), note('no')]

    const result = applyNoteFilters(notes, { filterTag: null, categoryFilter })

    expect(ids(result)).toEqual(['yes'])
  })

  it('태그와 카테고리를 함께 만족하는 노트만 남긴다', () => {
    const notes = [
      note('both', { tags: [{ name: 'work' }], hasLink: true }),
      note('tag-only', { tags: [{ name: 'work' }] }),
      note('link-only', { hasLink: true }),
    ]

    const result = applyNoteFilters(notes, { filterTag: 'work', categoryFilter: 'link' })

    expect(ids(result)).toEqual(['both'])
  })

  it('원본 배열을 건드리지 않는다', () => {
    const notes = [note('a', { hasLink: true }), note('b')]

    applyNoteFilters(notes, { filterTag: null, categoryFilter: 'link' })

    expect(ids(notes)).toEqual(['a', 'b'])
  })

  describe('inboxOnly (BRU-50)', () => {
    it('태그가 하나도 없는 노트만 남긴다', () => {
      const notes = [note('untagged'), note('tagged', { tags: [{ name: 'work' }] })]

      const result = applyNoteFilters(notes, {
        filterTag: null,
        categoryFilter: null,
        inboxOnly: true,
      })

      expect(ids(result)).toEqual(['untagged'])
    })

    it('꺼져 있으면 태그 붙은 노트도 그대로 남는다', () => {
      const notes = [note('untagged'), note('tagged', { tags: [{ name: 'work' }] })]

      const result = applyNoteFilters(notes, {
        filterTag: null,
        categoryFilter: null,
        inboxOnly: false,
      })

      expect(ids(result)).toEqual(['untagged', 'tagged'])
    })

    it('카테고리 필터와 함께 걸린다', () => {
      const notes = [
        note('untagged-link', { hasLink: true }),
        note('untagged-plain'),
        note('tagged-link', { tags: [{ name: 'work' }], hasLink: true }),
      ]

      const result = applyNoteFilters(notes, {
        filterTag: null,
        categoryFilter: 'link',
        inboxOnly: true,
      })

      expect(ids(result)).toEqual(['untagged-link'])
    })

    it('유예 목록에 있는 노트는 태그가 붙어도 자리를 지킨다', () => {
      // 태그 팝오버가 열려 있는 동안 노트가 사라지면 팝오버가 허공에 뜬다
      const notes = [note('being-tagged', { tags: [{ name: 'work' }] }), note('untagged')]

      const result = applyNoteFilters(notes, {
        filterTag: null,
        categoryFilter: null,
        inboxOnly: true,
        retainedNoteIds: new Set(['being-tagged']),
      })

      expect(ids(result)).toEqual(['being-tagged', 'untagged'])
    })

    it('유예된 노트라도 카테고리 필터는 그대로 통과해야 한다', () => {
      const notes = [note('being-tagged', { tags: [{ name: 'work' }] })]

      const result = applyNoteFilters(notes, {
        filterTag: null,
        categoryFilter: 'link',
        inboxOnly: true,
        retainedNoteIds: new Set(['being-tagged']),
      })

      expect(ids(result)).toEqual([])
    })

    it('inboxOnly가 꺼져 있으면 유예 목록은 아무 영향이 없다', () => {
      const notes = [note('a'), note('b', { tags: [{ name: 'work' }] })]

      const result = applyNoteFilters(notes, {
        filterTag: 'work',
        categoryFilter: null,
        inboxOnly: false,
        retainedNoteIds: new Set(['a']),
      })

      expect(ids(result)).toEqual(['b'])
    })
  })
})

describe('반출된 노트 (BRU-45)', () => {
  it('기본 목록에서는 반출된 노트가 빠진다 — 처리가 끝난 것이 계속 보이면 두 번 처리한다', () => {
    const notes = [note('a'), exported('b'), note('c')]

    const result = applyNoteFilters(notes, { filterTag: null, categoryFilter: null })

    expect(ids(result)).toEqual(['a', 'c'])
  })

  it('showExported를 켜면 반출된 노트도 보인다 — 되돌리려면 찾을 수 있어야 한다', () => {
    const notes = [note('a'), exported('b')]

    const result = applyNoteFilters(notes, {
      filterTag: null,
      categoryFilter: null,
      showExported: true,
    })

    expect(ids(result)).toEqual(['a', 'b'])
  })

  it('반출된 노트를 태그로 찾을 때도 숨김 규칙은 그대로다', () => {
    const notes = [exported('b', { tags: [{ name: 'work' }] })]

    expect(ids(applyNoteFilters(notes, { filterTag: 'work', categoryFilter: null }))).toEqual([])
    expect(
      ids(applyNoteFilters(notes, { filterTag: 'work', categoryFilter: null, showExported: true }))
    ).toEqual(['b'])
  })

  it('Inbox에는 반출된 노트가 뜨지 않는다 — 태그 없이 반출된 것도 처리가 끝난 것이다', () => {
    const notes = [note('a'), exported('b')]

    const result = applyNoteFilters(notes, {
      filterTag: null,
      categoryFilter: null,
      inboxOnly: true,
    })

    expect(ids(result)).toEqual(['a'])
  })

  it('Inbox 수에도 반출된 노트는 세지 않는다', () => {
    expect(countInboxNotes([note('a'), exported('b')])).toBe(1)
  })

  it('유예 목록에 있으면 반출돼도 자리를 지킨다 — 방금 반출한 줄이 눈앞에서 사라지지 않게', () => {
    const notes = [exported('b')]

    const result = applyNoteFilters(notes, {
      filterTag: null,
      categoryFilter: null,
      retainedNoteIds: new Set(['b']),
    })

    expect(ids(result)).toEqual(['b'])
  })
})

describe('프로젝트 필터 (BRU-83)', () => {
  it('filterProjectId가 있으면 그 프로젝트의 노트만 남긴다', () => {
    const notes = [
      note('in', { projectId: 'p1' }),
      note('other', { projectId: 'p2' }),
      note('none'),
    ]

    const result = applyNoteFilters(notes, {
      filterTag: null,
      categoryFilter: null,
      filterProjectId: 'p1',
    })

    expect(ids(result)).toEqual(['in'])
  })

  it('filterProjectId가 null이면 프로젝트로 걸러내지 않는다', () => {
    const notes = [note('a', { projectId: 'p1' }), note('b')]

    const result = applyNoteFilters(notes, {
      filterTag: null,
      categoryFilter: null,
      filterProjectId: null,
    })

    expect(ids(result)).toEqual(['a', 'b'])
  })

  it('UNASSIGNED_PROJECT_ID면 아직 프로젝트가 없는 노트만 남긴다 — 분류할 것을 찾는 길', () => {
    const notes = [note('a', { projectId: 'p1' }), note('b'), note('c', { projectId: null })]

    const result = applyNoteFilters(notes, {
      filterTag: null,
      categoryFilter: null,
      filterProjectId: UNASSIGNED_PROJECT_ID,
    })

    expect(ids(result)).toEqual(['b', 'c'])
  })

  it('태그 필터와 AND로 걸린다', () => {
    const notes = [
      note('both', { projectId: 'p1', tags: [{ name: 'work' }] }),
      note('project-only', { projectId: 'p1' }),
      note('tag-only', { tags: [{ name: 'work' }] }),
    ]

    const result = applyNoteFilters(notes, {
      filterTag: 'work',
      categoryFilter: null,
      filterProjectId: 'p1',
    })

    expect(ids(result)).toEqual(['both'])
  })

  it('프로젝트를 막 지정한 노트는 팝오버가 닫힐 때까지 자리를 지킨다', () => {
    // 미분류만 보다가 프로젝트를 고르는 순간 줄이 사라지면 무슨 일이 일어났는지 알 수 없다
    const notes = [note('being-assigned', { projectId: 'p1' }), note('untouched')]

    const result = applyNoteFilters(notes, {
      filterTag: null,
      categoryFilter: null,
      filterProjectId: UNASSIGNED_PROJECT_ID,
      retainedNoteIds: new Set(['being-assigned']),
    })

    expect(ids(result)).toEqual(['being-assigned', 'untouched'])
  })
})

describe('isExportedNote', () => {
  it('URL이 있으면 반출된 것이다', () => {
    expect(isExportedNote({ linearIssueUrl: 'https://linear.app/x' })).toBe(true)
  })

  it('URL이 없으면 반출되지 않은 것이다', () => {
    expect(isExportedNote({ linearIssueUrl: null })).toBe(false)
  })
})

describe('isUntaggedNote', () => {
  it('태그가 비어 있으면 참이다', () => {
    expect(isUntaggedNote({ tags: [] })).toBe(true)
  })

  it('태그가 하나라도 있으면 거짓이다', () => {
    expect(isUntaggedNote({ tags: [{ name: 'work' }] })).toBe(false)
  })
})

describe('countInboxNotes', () => {
  it('태그 없는 최상위 노트 수를 센다', () => {
    const notes = [note('a'), note('b'), note('c', { tags: [{ name: 'work' }] })]

    expect(countInboxNotes(notes)).toBe(2)
  })

  it('답글(자식 노트)은 세지 않는다 — 목록에 뜨는 줄 수와 맞춘다', () => {
    const notes = [note('root'), note('reply', { parentId: 'root' })]

    expect(countInboxNotes(notes)).toBe(1)
  })

  it('태그를 붙이면 즉시 줄어든다', () => {
    const notes = [note('a'), note('b')]
    expect(countInboxNotes(notes)).toBe(2)

    const afterTagging = [note('a', { tags: [{ name: 'work' }] }), note('b')]
    expect(countInboxNotes(afterTagging)).toBe(1)
  })

  it('비어 있으면 0이다', () => {
    expect(countInboxNotes([])).toBe(0)
  })
})

// ============================================================
// 할일 필터 (BRU-175)
// ============================================================

/** 타입·완료 상태를 갖춘 노트 — 기존 note()는 두 필드를 모르므로 여기서 채운다 */
function todoNote(id: string, overrides: Partial<TestNote> = {}): TestNote {
  return note(id, { type: 'note', completedAt: null, ...overrides })
}

const filterTodo = (notes: TestNote[], opts: Partial<NoteFilterOptions>) =>
  applyNoteFilters(notes, { filterTag: null, categoryFilter: null, ...opts })

describe('할일 필터 — todoFilter (BRU-175)', () => {
  const plain = todoNote('plain')
  const open = todoNote('open', { type: 'todo' })
  const done = todoNote('done', { type: 'todo', completedAt: new Date('2026-08-29') })
  const all = [plain, open, done]

  it('기본(null)은 아무것도 걸러내지 않는다', () => {
    expect(ids(filterTodo(all, { todoFilter: null }))).toEqual(['plain', 'open', 'done'])
  })

  // 완료된 것을 빼지 않는 이유: 방금 끝낸 것이 눈앞에서 사라지면 무슨 일이
  // 일어났는지 알 수 없다. 목록에는 남기고 화면에서 흐리게 그린다.
  it("'todo'는 할일만 남긴다 — 완료된 것도 포함", () => {
    expect(ids(filterTodo(all, { todoFilter: 'todo' }))).toEqual(['open', 'done'])
  })

  it("'open'은 아직 안 끝난 할일만 남긴다", () => {
    expect(ids(filterTodo(all, { todoFilter: 'open' }))).toEqual(['open'])
  })

  it('일반 노트는 어떤 할일 필터에도 걸리지 않는다', () => {
    expect(ids(filterTodo([plain], { todoFilter: 'todo' }))).toEqual([])
    expect(ids(filterTodo([plain], { todoFilter: 'open' }))).toEqual([])
  })

  it('다른 필터와 AND로 걸린다', () => {
    const tagged = todoNote('tagged', { type: 'todo', tags: [{ name: 'work' }] })
    const result = filterTodo([...all, tagged], { todoFilter: 'todo', filterTag: 'work' })
    expect(ids(result)).toEqual(['tagged'])
  })

  // 완료 시각이 남은 일반 노트는 DB CHECK가 막지만, 제약이 한 겹 뚫려도
  // 그 노트가 할일 목록에 끼어들면 안 된다
  it('타입이 note면 완료 시각이 있어도 할일이 아니다', () => {
    const impossible = todoNote('impossible', { completedAt: new Date() })
    expect(ids(filterTodo([impossible], { todoFilter: 'todo' }))).toEqual([])
  })
})

describe('countOpenTodos — 미완료 할일 수 (BRU-175)', () => {
  it('완료되지 않은 할일만 센다', () => {
    const notes = [
      todoNote('a', { type: 'todo' }),
      todoNote('b', { type: 'todo', completedAt: new Date() }),
      todoNote('c'),
    ]
    expect(countOpenTodos(notes)).toBe(1)
  })

  // 답글은 피드에서 줄로 서지 않는다 — countInboxNotes와 같은 규칙이다
  it('답글은 세지 않는다', () => {
    const notes = [
      todoNote('root', { type: 'todo' }),
      todoNote('reply', { type: 'todo', parentId: 'root' }),
    ]
    expect(countOpenTodos(notes)).toBe(1)
  })

  it('반출된 할일은 세지 않는다', () => {
    const notes = [
      todoNote('a', { type: 'todo' }),
      todoNote('b', {
        type: 'todo',
        linearIssueUrl: 'https://linear.app/intellieffect/issue/BRU-96/x',
      }),
    ]
    expect(countOpenTodos(notes)).toBe(1)
  })
})
