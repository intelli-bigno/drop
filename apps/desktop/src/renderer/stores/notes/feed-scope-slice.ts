import type { StateCreator } from 'zustand'
import type { NotesState, FeedScopeSlice } from './types'

/**
 * 피드 범위 필터 (BRU-199) — Inbox(BRU-50)와 할일(BRU-175)을 한 축으로 합친 것.
 *
 * 뷰 모드가 아니라 활성 뷰 위에 걸리는 필터다. 새 컬럼도, 새 테이블도 없다.
 *
 * 태그 필터와는 동시에 켤 수 없다 — "#work인데 태그가 없는 노트"는 항상 빈
 * 목록이라 켜는 즉시 서로를 끈다. 이 규칙은 Inbox 갈래에만 해당한다:
 * "#work 태그가 붙은 할일"은 얼마든지 있을 수 있으므로 할일 갈래는 태그를 끄지 않는다.
 */
export const createFeedScopeSlice: StateCreator<NotesState, [], [], FeedScopeSlice> = (set) => ({
  feedScope: null,

  setFeedScope: (feedScope) => {
    set(feedScope === 'inbox' ? { feedScope, filterTag: null } : { feedScope })
  },
})
