import { describe, expect, it } from 'vitest'
import {
  FEED_SCOPE_CYCLE,
  nextFeedScope,
  scopeExcludesTag,
  type FeedScope,
} from '../feed-scope'

describe('nextFeedScope', () => {
  it('전체 → Inbox → 할일 → 남은 할일 → 전체 로 돈다', () => {
    expect(nextFeedScope(null)).toBe('inbox')
    expect(nextFeedScope('inbox')).toBe('todo')
    expect(nextFeedScope('todo')).toBe('open')
    expect(nextFeedScope('open')).toBeNull()
  })

  it('네 번 누르면 제자리로 돌아온다 — 어느 상태에서 시작하든', () => {
    const start: FeedScope[] = [null, 'inbox', 'todo', 'open']
    for (const scope of start) {
      let cur = scope
      for (let i = 0; i < FEED_SCOPE_CYCLE.length; i++) cur = nextFeedScope(cur)
      expect(cur).toBe(scope)
    }
  })

  it('순환에 모든 상태가 정확히 한 번씩 들어 있다 — 도달 못 하는 상태가 없어야 한다', () => {
    expect(FEED_SCOPE_CYCLE).toEqual([null, 'inbox', 'todo', 'open'])
    expect(new Set(FEED_SCOPE_CYCLE).size).toBe(FEED_SCOPE_CYCLE.length)
  })
})

// 태그 필터와의 상호배제 규칙 (BRU-204).
// 두 슬라이스가 각자 삼항으로 판단하면 방향이 어긋난다 — 실제로 어긋나 있었다.
describe('scopeExcludesTag', () => {
  it('Inbox만 태그 필터와 겹칠 수 없다 — "#work인데 태그가 없는 노트"는 항상 빈 목록이다', () => {
    expect(scopeExcludesTag('inbox')).toBe(true)
  })

  it('할일 갈래는 태그와 함께 걸린다 — "#work 태그가 붙은 할일"은 얼마든지 있다', () => {
    expect(scopeExcludesTag('todo')).toBe(false)
    expect(scopeExcludesTag('open')).toBe(false)
  })

  it('범위가 꺼져 있으면 끌 것도 없다', () => {
    expect(scopeExcludesTag(null)).toBe(false)
  })
})
