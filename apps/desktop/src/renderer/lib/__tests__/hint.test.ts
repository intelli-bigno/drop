/**
 * @vitest-environment jsdom
 */
import { describe, it, expect } from 'vitest'
import { HINT_GAP, HINT_MARGIN, placeHint, readHint } from '../hint'

function el(attrs: Record<string, string>, tag = 'button'): HTMLElement {
  const node = document.createElement(tag)
  for (const [key, value] of Object.entries(attrs)) node.setAttribute(key, value)
  return node
}

describe('readHint', () => {
  it('설명과 글쇠를 함께 읽는다 — 힌트의 요점이 그 둘이 한 번에 보이는 것이다', () => {
    expect(readHint(el({ 'data-hint': '검색', 'data-hint-keys': '⌘K' }))).toEqual({
      label: '검색',
      keys: '⌘K',
    })
  })

  it('글쇠가 없는 조작도 설명만으로 힌트가 선다', () => {
    expect(readHint(el({ 'data-hint': '모두 펼쳐보기' }))).toEqual({
      label: '모두 펼쳐보기',
      keys: null,
    })
  })

  it('빈 글쇠는 없는 것으로 본다 — 빈 알약이 뜨면 안 된다', () => {
    expect(readHint(el({ 'data-hint': '보관', 'data-hint-keys': '  ' }))?.keys).toBeNull()
  })

  it('표시가 없으면 힌트도 없다', () => {
    expect(readHint(el({}))).toBeNull()
    expect(readHint(null)).toBeNull()
  })

  it('안쪽 아이콘에 커서가 닿아도 바깥 버튼의 힌트를 찾는다', () => {
    const button = el({ 'data-hint': '삭제', 'data-hint-keys': 'Delete' })
    const icon = el({}, 'svg')
    button.appendChild(icon)
    expect(readHint(icon)?.label).toBe('삭제')
  })
})

describe('placeHint', () => {
  const viewport = { width: 1000, height: 800 }
  const bubble = { width: 120, height: 32 }

  it('기본은 아래, 가운데 정렬', () => {
    const place = placeHint({ left: 400, top: 100, width: 40, height: 30 }, bubble, viewport)
    expect(place.side).toBe('below')
    expect(place.top).toBe(100 + 30 + HINT_GAP)
    expect(place.left).toBe(400 + 20 - 60)
  })

  it('아래에 자리가 없으면 위로 뒤집는다', () => {
    const place = placeHint({ left: 400, top: 760, width: 40, height: 30 }, bubble, viewport)
    expect(place.side).toBe('above')
    expect(place.top).toBe(760 - HINT_GAP - bubble.height)
  })

  it('오른쪽 끝 버튼의 힌트가 화면 밖으로 나가지 않는다 — 헤더 맨 오른쪽이 실제 자리다', () => {
    const place = placeHint({ left: 970, top: 10, width: 30, height: 30 }, bubble, viewport)
    expect(place.left).toBe(viewport.width - bubble.width - HINT_MARGIN)
  })

  it('왼쪽 끝에서도 마찬가지다', () => {
    const place = placeHint({ left: 0, top: 10, width: 30, height: 30 }, bubble, viewport)
    expect(place.left).toBe(HINT_MARGIN)
  })
})
