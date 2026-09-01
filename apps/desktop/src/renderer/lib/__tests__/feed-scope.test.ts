import { describe, expect, it } from 'vitest'
import { FEED_SCOPE_CYCLE, nextFeedScope, type FeedScope } from '../feed-scope'

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
