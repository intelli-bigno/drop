import { describe, it, expect } from 'vitest'
import { SEARCH_LIMIT, buildSnippet, searchNotes } from '../note-search'

type Fixture = Parameters<typeof searchNotes>[0][number]

function note(over: Partial<Fixture> = {}): Fixture {
  return { id: 'n1', displayId: 1, content: '아무 내용', tags: [], ...over }
}

const textOf = (segments: { text: string }[]) => segments.map((s) => s.text).join('')
const matched = (segments: { text: string; match: boolean }[]) =>
  segments.filter((s) => s.match).map((s) => s.text)

describe('searchNotes', () => {
  it('빈 검색어에는 아무것도 걸리지 않는다 — 공백만 쳐도 마찬가지다', () => {
    expect(searchNotes([note()], '').hits).toEqual([])
    expect(searchNotes([note()], '   ').total).toBe(0)
  })

  it('대소문자를 접어서 본다', () => {
    const notes = [note({ content: 'Deploy 스크립트를 고쳤다' })]
    expect(searchNotes(notes, 'deploy').hits).toHaveLength(1)
    expect(searchNotes(notes, 'DEPLOY').hits).toHaveLength(1)
  })

  it('태그로도 찾는다 — 화면에 태그를 보여주면서 태그로 못 찾는 것은 거짓말이다', () => {
    const notes = [note({ content: '본문에는 없다', tags: [{ name: '배포' }] })]
    expect(searchNotes(notes, '배포').hits).toHaveLength(1)
    expect(searchNotes(notes, '#배포').hits).toHaveLength(1)
  })

  it('번호로도 찾는다 — 노트를 번호로 부르는 자리가 이미 있다', () => {
    const notes = [note({ displayId: 142, content: '전혀 다른 말' })]
    expect(searchNotes(notes, '142').hits).toHaveLength(1)
    expect(searchNotes(notes, '#142').hits).toHaveLength(1)
    // 부분 일치로 번호를 긁지 않는다 — 14를 쳤다고 142가 나오면 번호가 번호가 아니다
    expect(searchNotes(notes, '14').hits).toHaveLength(0)
  })

  it('개수는 자른 뒤가 아니라 전부를 센다 — 스무 개까지만 그리면서 "20개"라고 하면 거짓말이다', () => {
    const many = Array.from({ length: 25 }, (_, i) => note({ id: `n${i}`, content: '같은 말' }))
    const result = searchNotes(many, '같은 말')
    expect(result.hits).toHaveLength(SEARCH_LIMIT)
    expect(result.total).toBe(25)
  })
})

describe('buildSnippet', () => {
  it('맞은 자리를 표시한다', () => {
    const segments = buildSnippet('오늘 배포를 마쳤다', '배포')
    expect(matched(segments)).toEqual(['배포'])
  })

  it('원문을 잃지 않는다 — 토막을 도로 이으면 보여줄 글자가 그대로 나온다', () => {
    const segments = buildSnippet('오늘 배포를 마쳤다', '배포')
    expect(textOf(segments)).toBe('오늘 배포를 마쳤다')
  })

  it('맞은 자리가 멀리 있으면 그 언저리를 잘라 온다 — 앞머리만 보여주면 왜 걸렸는지 알 수 없다', () => {
    const content = `${'가'.repeat(300)}열쇠말${'나'.repeat(300)}`
    const segments = buildSnippet(content, '열쇠말')
    expect(matched(segments)).toEqual(['열쇠말'])
    expect(textOf(segments)).toContain('열쇠말')
    expect(textOf(segments).length).toBeLessThan(140)
    expect(textOf(segments).startsWith('…')).toBe(true)
    expect(textOf(segments).endsWith('…')).toBe(true)
  })

  it('맞은 자리를 앞쪽에 둔다 — 한 줄은 폭이 좁아서, 가운데에 두면 말줄임에 잘려 안 보인다', () => {
    const content = `${'가'.repeat(300)}열쇠말${'나'.repeat(300)}`
    const text = textOf(buildSnippet(content, '열쇠말'))
    // `…` 다음 몇 글자만 지나면 바로 맞은 자리가 나와야 한다
    expect(text.indexOf('열쇠말')).toBeLessThanOrEqual(12)
  })

  it('마크다운 마커를 걷고 한 줄로 만든다 — 목록에 `## `가 보일 이유가 없다', () => {
    const segments = buildSnippet('## 회의 메모\n- 배포 일정', '배포')
    expect(textOf(segments)).toBe('회의 메모 배포 일정')
  })

  it('같은 말이 여러 번 나오면 여러 번 표시한다', () => {
    const segments = buildSnippet('배포 다음에 또 배포', '배포')
    expect(matched(segments)).toEqual(['배포', '배포'])
  })

  it('본문에 없는 말(태그·번호로 걸린 노트)이면 앞머리를 그대로 보여준다', () => {
    const segments = buildSnippet('본문에는 없다', '배포')
    expect(matched(segments)).toEqual([])
    expect(textOf(segments)).toBe('본문에는 없다')
  })

  it('빈 본문에도 터지지 않는다', () => {
    expect(buildSnippet('', '배포')).toEqual([])
  })
})
