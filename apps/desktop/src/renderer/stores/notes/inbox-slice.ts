import type { StateCreator } from 'zustand'
import type { NotesState, InboxSlice } from './types'

/**
 * Inbox 필터 (BRU-50) — 태그가 하나도 없는 활성 노트만 본다.
 *
 * 뷰 모드가 아니라 활성 뷰 위에 걸리는 필터다. 새 컬럼도, 새 테이블도 없고
 * 이미 있는 note.tags가 비었는지만 본다.
 *
 * 태그 필터와는 동시에 켤 수 없다 — "#work인데 태그가 없는 노트"는 항상 빈
 * 목록이라 켜는 즉시 서로를 끈다.
 */
export const createInboxSlice: StateCreator<NotesState, [], [], InboxSlice> = (set) => ({
  inboxOnly: false,

  setInboxOnly: (inboxOnly) => {
    set(inboxOnly ? { inboxOnly: true, filterTag: null } : { inboxOnly: false })
  },
})
