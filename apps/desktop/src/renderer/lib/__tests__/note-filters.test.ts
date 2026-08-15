import { describe, it, expect } from 'vitest'
import {
  applyNoteFilters,
  countInboxNotes,
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
    ...overrides,
  }
}

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
