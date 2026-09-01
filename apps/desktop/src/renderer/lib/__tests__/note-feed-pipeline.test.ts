import { describe, it, expect } from 'vitest'
import { applyNoteFilters } from '../note-filters'
import { buildNoteRows } from '../note-hierarchy'

/**
 * 피드가 실제로 거치는 경로 전체 — 필터 → 계층 묶음 (BRU-70).
 *
 * 단위 테스트는 두 조각을 따로 본다. 이 이슈의 버그는 **조각 사이**에 있었다:
 * 필터가 부모를 걷어내면 계층 묶음이 그 답글을 어디에도 못 넣고 흘렸다.
 * 그래서 두 함수를 이어 붙인 채로 검증한다.
 */
describe('노트 피드 파이프라인 (필터 → 계층)', () => {
  interface TestNote {
    id: string
    parentId: string | null
    tags: Array<{ name: string }>
    hasLink: boolean
    hasMedia: boolean
    hasFiles: boolean
    content: string
    createdAt: Date
  }

  const note = (id: string, overrides: Partial<TestNote> = {}): TestNote => ({
    id,
    parentId: null,
    tags: [],
    hasLink: false,
    hasMedia: false,
    hasFiles: false,
    content: id,
    createdAt: new Date('2026-08-01T00:00:00Z'),
    ...overrides,
  })

  /** 피드가 하는 일 그대로: 필터를 걸고, 그 결과를 계층으로 묶는다 */
  const feed = (notes: TestNote[], options: Parameters<typeof applyNoteFilters>[1]) =>
    buildNoteRows(applyNoteFilters(notes, options), notes)

  const 부모 = note('부모', { content: '분기 회고', tags: [{ name: 'work' }] })
  const 답글 = note('답글', {
    parentId: '부모',
    content: '스프린트 회고 후속',
    createdAt: new Date('2026-08-01T01:00:00Z'),
  })
  const 남 = note('남', { content: '장보기' })

  it('검색이 답글에만 걸려도 답글이 사라지지 않고 부모와 함께 나온다', () => {
    // 이 이슈의 증상 그대로: 걸린 것은 답글뿐이고 부모는 필터 밖이다.
    // 종전 동작에서는 답글이 뿌리도 자식도 되지 못해 통째로 증발했다.
    const 검색결과 = [답글]

    const rows = buildNoteRows(검색결과, [부모, 답글, 남])

    expect(rows.map((r) => r.note.id)).toEqual(['부모', '답글'])
    expect(rows.map((r) => r.depth)).toEqual([0, 1])
    expect(rows.map((r) => r.isContextOnly)).toEqual([true, false])
  })

  /**
   * 위쪽(조상)은 끌어오고 아래쪽(자손)은 끌어오지 않는다 — 일부러 비대칭이다.
   * 조상은 "이 답글이 무엇에 달렸는지"라 없으면 답글을 읽을 수 없지만,
   * 자손까지 끌어오면 `#work`를 걸었는데 태그 없는 답글이 줄줄이 따라 나온다.
   * 종전 동작도 자손은 걸러냈다 — 이 PR이 바꾸는 것은 조상 쪽뿐이다.
   */
  it('부모가 걸리고 답글이 안 걸리면 답글은 나오지 않는다 (종전과 같다)', () => {
    const rows = feed([부모, 답글, 남], { filterTag: 'work', categoryFilter: null })

    expect(rows.map((r) => r.note.id)).toEqual(['부모'])
  })

  it('Inbox 필터에서도 답글이 부모를 잃지 않는다', () => {
    // Inbox = 태그 없는 노트. 부모(work 태그)는 빠지고 답글만 남는 상황.
    const rows = feed([부모, 답글, 남], {
      filterTag: null,
      categoryFilter: null,
      feedScope: 'inbox',
    })

    expect(rows.map((r) => r.note.id)).toEqual(['부모', '답글', '남'])
    // 부모는 Inbox 결과가 아니라 맥락으로 딸려 온 것이다
    expect(rows.map((r) => r.isContextOnly)).toEqual([true, false, false])
  })

  it('카테고리 필터에 답글만 걸려도 부모를 끌어와 계층을 지킨다', () => {
    const 부모없는링크 = note('부모')
    const 링크답글 = note('링크답글', {
      parentId: '부모',
      hasLink: true,
      createdAt: new Date('2026-08-01T02:00:00Z'),
    })

    const rows = feed([부모없는링크, 링크답글], { filterTag: null, categoryFilter: 'link' })

    expect(rows.map((r) => r.note.id)).toEqual(['부모', '링크답글'])
    expect(rows.map((r) => r.isContextOnly)).toEqual([true, false])
  })

  it('필터가 없으면 종전과 같은 평평한 순서 + 답글 들여쓰기다', () => {
    const rows = feed([부모, 답글, 남], { filterTag: null, categoryFilter: null })

    expect(rows.map((r) => r.note.id)).toEqual(['부모', '답글', '남'])
    expect(rows.map((r) => r.depth)).toEqual([0, 1, 0])
    expect(rows.every((r) => !r.isContextOnly)).toBe(true)
  })

  it('부모가 다른 뷰(보관함)에 있으면 답글만 최상위로 올라오고 표시가 붙는다', () => {
    // 보관된 부모는 활성 목록(baseNotes)에 아예 없다
    const rows = feed([답글, 남], { filterTag: null, categoryFilter: null })

    expect(rows.map((r) => r.note.id)).toEqual(['답글', '남'])
    expect(rows.map((r) => r.isOrphanedReply)).toEqual([true, false])
  })
})
