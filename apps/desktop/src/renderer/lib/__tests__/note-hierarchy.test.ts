import { describe, it, expect } from 'vitest'
import { buildNoteRows, type HierarchicalNote } from '../note-hierarchy'

function note(id: string, overrides: Partial<HierarchicalNote> = {}): HierarchicalNote {
  return {
    id,
    parentId: null,
    createdAt: new Date('2026-08-01T00:00:00Z'),
    ...overrides,
  }
}

function reply(id: string, parentId: string, minute: number): HierarchicalNote {
  return note(id, {
    parentId,
    createdAt: new Date(Date.UTC(2026, 7, 1, 0, minute, 0)),
  })
}

const ids = (rows: ReturnType<typeof buildNoteRows>) => rows.map((r) => r.note.id)
const depths = (rows: ReturnType<typeof buildNoteRows>) => rows.map((r) => r.depth)

describe('buildNoteRows', () => {
  it('빈 목록은 행도 없다', () => {
    expect(buildNoteRows([], [])).toEqual([])
  })

  it('답글을 부모 바로 아래에 한 단 들여쓴다', () => {
    const parent = note('부모')
    const child = reply('답글', '부모', 10)

    const rows = buildNoteRows([parent, child], [parent, child])

    expect(ids(rows)).toEqual(['부모', '답글'])
    expect(depths(rows)).toEqual([0, 1])
  })

  it('형제 답글은 오래된 것부터', () => {
    const parent = note('부모')
    const late = reply('나중', '부모', 30)
    const early = reply('먼저', '부모', 10)

    const rows = buildNoteRows([parent, late, early], [parent, late, early])

    expect(ids(rows)).toEqual(['부모', '먼저', '나중'])
  })

  it('최상위 노트 순서는 넘겨받은 순서를 지킨다', () => {
    const notes = [note('a'), note('b'), note('c')]

    expect(ids(buildNoteRows(notes, notes))).toEqual(['a', 'b', 'c'])
  })

  it('데스크톱은 들여쓰기 깊이를 제한하지 않는다 — 화면이 넓다', () => {
    const chain = [note('1'), reply('2', '1', 10), reply('3', '2', 20), reply('4', '3', 30)]

    expect(depths(buildNoteRows(chain, chain))).toEqual([0, 1, 2, 3])
  })

  // BRU-70 — 지금까지 답글이 통째로 사라지던 자리
  describe('부모가 필터·검색에서 빠졌을 때', () => {
    it('답글만 검색에 걸려도 사라지지 않고 부모와 함께 보인다', () => {
      const parent = note('부모')
      const child = reply('답글', '부모', 10)

      // 검색어가 답글에만 걸린 상황: visible에는 답글만 있다
      const rows = buildNoteRows([child], [parent, child])

      expect(ids(rows)).toEqual(['부모', '답글'])
      expect(depths(rows)).toEqual([0, 1])
    })

    it('맥락으로 끌어온 부모는 그렇게 표시된다 — 검색 결과인 척하지 않는다', () => {
      const parent = note('부모')
      const child = reply('답글', '부모', 10)

      const rows = buildNoteRows([child], [parent, child])

      expect(rows.map((r) => r.isContextOnly)).toEqual([true, false])
    })

    it('조부모까지 이어 올라간다', () => {
      const all = [note('조부'), reply('부', '조부', 10), reply('손', '부', 20)]

      const rows = buildNoteRows([all[2]], all)

      expect(ids(rows)).toEqual(['조부', '부', '손'])
      expect(rows.map((r) => r.isContextOnly)).toEqual([true, true, false])
    })

    it('끌어온 부모가 걸리지 않은 다른 답글까지 데려오지는 않는다', () => {
      const parent = note('부모')
      const matched = reply('걸린답글', '부모', 10)
      const other = reply('안걸린답글', '부모', 20)

      const rows = buildNoteRows([matched], [parent, matched, other])

      expect(ids(rows)).toEqual(['부모', '걸린답글'])
    })

    it('부모가 다른 뷰(보관·휴지통)에 있으면 답글을 버리지 않고 최상위로 올린다', () => {
      const orphan = reply('답글', '보관된부모', 10)

      const rows = buildNoteRows([orphan], [orphan])

      expect(ids(rows)).toEqual(['답글'])
      expect(depths(rows)).toEqual([0])
      expect(rows.map((r) => r.isOrphanedReply)).toEqual([true])
    })
  })

  describe('망가진 데이터', () => {
    it('자기 자신을 부모로 가리켜도 사라지지 않는다', () => {
      const loop = note('고리', { parentId: '고리' })

      expect(ids(buildNoteRows([loop], [loop]))).toEqual(['고리'])
    })

    it('두 노트가 서로를 가리켜도 둘 다 남는다', () => {
      const a = note('가', { parentId: '나' })
      const b = note('나', { parentId: '가' })

      expect(ids(buildNoteRows([a, b], [a, b])).sort()).toEqual(['가', '나'])
    })

    it('같은 노트가 두 번 들어와도 행은 한 번만 난다', () => {
      const dup = note('a')

      expect(ids(buildNoteRows([dup, dup], [dup, dup]))).toEqual(['a'])
    })
  })
})
