import { describe, it, expect } from 'vitest'
import { rovingIndex, resolveActionBarKey } from '../action-bar'

describe('rovingIndex', () => {
  it('한 칸씩 옆으로 간다', () => {
    expect(rovingIndex(0, 5, 1)).toBe(1)
    expect(rovingIndex(3, 5, -1)).toBe(2)
  })

  it('끝에서 반대편으로 돈다 — 막다른 곳에서 손이 멈추면 되돌아가야 한다', () => {
    expect(rovingIndex(4, 5, 1)).toBe(0)
    expect(rovingIndex(0, 5, -1)).toBe(4)
  })

  it('버튼이 없으면 -1이다 — 없는 자리를 고르게 두지 않는다', () => {
    expect(rovingIndex(0, 0, 1)).toBe(-1)
  })
})

describe('resolveActionBarKey', () => {
  it('좌우로 옮긴다 — 가로로 선 줄이라 좌우가 먼저다', () => {
    expect(resolveActionBarKey('ArrowRight')).toEqual({ type: 'move', delta: 1 })
    expect(resolveActionBarKey('ArrowLeft')).toEqual({ type: 'move', delta: -1 })
  })

  it('위아래도 같은 일을 한다 — "방향키로 고른다"는 말에 위아래가 빠질 이유가 없다', () => {
    expect(resolveActionBarKey('ArrowDown')).toEqual({ type: 'move', delta: 1 })
    expect(resolveActionBarKey('ArrowUp')).toEqual({ type: 'move', delta: -1 })
  })

  it('Esc는 닫는다', () => {
    expect(resolveActionBarKey('Escape')).toEqual({ type: 'close' })
  })

  it('Enter·Space는 우리가 가로채지 않는다 — 버튼이 스스로 눌린다', () => {
    expect(resolveActionBarKey('Enter')).toBeNull()
    expect(resolveActionBarKey(' ')).toBeNull()
  })

  it('나머지 글쇠는 그냥 흘려보낸다', () => {
    expect(resolveActionBarKey('a')).toBeNull()
  })
})
