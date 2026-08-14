import { describe, it, expect } from 'vitest'
import type { Tag } from '@drop/shared'
import {
  normalizeTagName,
  rankTagSuggestions,
  shouldShowCreateOption,
  moveSelection,
  shouldOpenTagPopoverOnEditEnd,
} from '../tag-popover'

function tag(name: string, lastUsedAt: string | null, id = name): Tag {
  return {
    id,
    name,
    createdAt: new Date('2026-01-01T00:00:00Z'),
    lastUsedAt: lastUsedAt ? new Date(lastUsedAt) : null,
  }
}

describe('normalizeTagName', () => {
  it('앞뒤 공백을 떼고 소문자로 맞춘다', () => {
    expect(normalizeTagName('  Drop  ')).toBe('drop')
  })
})

describe('rankTagSuggestions', () => {
  const allTags = [
    tag('drop', '2026-08-01T00:00:00Z'),
    tag('idea', '2026-08-10T00:00:00Z'),
    tag('meeting', null),
  ]

  it('입력이 없으면 최근 쓴 순으로 준다', () => {
    const result = rankTagSuggestions({ allTags, attachedTagNames: [], query: '' })
    expect(result.map((s) => s.name)).toEqual(['idea', 'drop', 'meeting'])
  })

  it('한 번도 안 쓴 태그는 뒤로 민다', () => {
    const result = rankTagSuggestions({
      allTags: [tag('meeting', null), tag('drop', '2026-08-01T00:00:00Z')],
      attachedTagNames: [],
      query: '',
    })
    expect(result.map((s) => s.name)).toEqual(['drop', 'meeting'])
  })

  it('최근 사용 시각이 같으면 자주 쓴 순으로 준다', () => {
    const result = rankTagSuggestions({
      allTags: [tag('a', '2026-08-01T00:00:00Z'), tag('b', '2026-08-01T00:00:00Z')],
      attachedTagNames: [],
      usageCounts: { a: 1, b: 9 },
      query: '',
    })
    expect(result.map((s) => s.name)).toEqual(['b', 'a'])
  })

  it('입력이 있으면 부분 일치로 좁힌다', () => {
    const result = rankTagSuggestions({ allTags, attachedTagNames: [], query: 'ee' })
    expect(result.map((s) => s.name)).toEqual(['meeting'])
  })

  it('앞부분 일치를 가운데 일치보다 앞에 둔다', () => {
    const result = rankTagSuggestions({
      allTags: [tag('release', '2026-08-01T00:00:00Z'), tag('lease', '2026-08-01T00:00:00Z')],
      attachedTagNames: [],
      query: 'lea',
    })
    expect(result.map((s) => s.name)).toEqual(['lease', 'release'])
  })

  it('대소문자를 무시하고 좁힌다', () => {
    const result = rankTagSuggestions({ allTags, attachedTagNames: [], query: 'ID' })
    expect(result.map((s) => s.name)).toEqual(['idea'])
  })

  it('이미 붙은 태그도 목록에 남기고 attached로 표시한다', () => {
    const result = rankTagSuggestions({ allTags, attachedTagNames: ['drop'], query: '' })
    expect(result.find((s) => s.name === 'drop')?.attached).toBe(true)
    expect(result.find((s) => s.name === 'idea')?.attached).toBe(false)
  })

  it('limit만큼만 준다', () => {
    const result = rankTagSuggestions({ allTags, attachedTagNames: [], query: '', limit: 2 })
    expect(result).toHaveLength(2)
  })
})

describe('shouldShowCreateOption', () => {
  const allTags = [tag('drop', null)]

  it('입력이 비어 있으면 만들지 않는다', () => {
    expect(shouldShowCreateOption({ allTags, query: '   ' })).toBe(false)
  })

  it('이미 있는 이름이면 만들지 않는다', () => {
    expect(shouldShowCreateOption({ allTags, query: ' DROP ' })).toBe(false)
  })

  it('없는 이름이면 만든다', () => {
    expect(shouldShowCreateOption({ allTags, query: 'inbox' })).toBe(true)
  })
})

describe('moveSelection', () => {
  it('아래로 움직인다', () => {
    expect(moveSelection(0, 1, 3)).toBe(1)
  })

  it('끝에서 더 내려가지 않는다', () => {
    expect(moveSelection(2, 1, 3)).toBe(2)
  })

  it('처음에서 더 올라가지 않는다', () => {
    expect(moveSelection(0, -1, 3)).toBe(0)
  })

  it('항목이 없으면 0이다', () => {
    expect(moveSelection(0, 1, 0)).toBe(0)
  })

  it('목록이 줄어들면 마지막 항목으로 맞춘다', () => {
    expect(moveSelection(5, 0, 3)).toBe(2)
  })
})

describe('shouldOpenTagPopoverOnEditEnd', () => {
  it('편집에서 본문을 바꾸고 나오면 연다', () => {
    expect(
      shouldOpenTagPopoverOnEditEnd({ contentChanged: true, content: '메모', isLocked: false })
    ).toBe(true)
  })

  it('아무것도 안 고치고 나오면 열지 않는다', () => {
    expect(
      shouldOpenTagPopoverOnEditEnd({ contentChanged: false, content: '메모', isLocked: false })
    ).toBe(false)
  })

  it('본문이 비어 있으면 열지 않는다', () => {
    expect(
      shouldOpenTagPopoverOnEditEnd({ contentChanged: true, content: '  \n ', isLocked: false })
    ).toBe(false)
  })

  it('잠긴 노트에서는 열지 않는다', () => {
    expect(
      shouldOpenTagPopoverOnEditEnd({ contentChanged: true, content: '메모', isLocked: true })
    ).toBe(false)
  })
})
