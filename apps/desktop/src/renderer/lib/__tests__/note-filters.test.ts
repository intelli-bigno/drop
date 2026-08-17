import { describe, it, expect } from 'vitest'
import {
  applyNoteFilters,
  countInboxNotes,
  isExportedNote,
  isUntaggedNote,
  type FilterableNote,
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
