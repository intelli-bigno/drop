// 쇼케이스 스토어 주입 (BRU-172).
//
// 쇼케이스는 실물 컴포넌트를 그대로 렌더한다 — 그래서 실물 스토어를 쓴다.
// 위험은 하나다: 화면 안에서 누른 버튼이 **진짜 Supabase로 나가는 것.**
// 쇼케이스에서 노트를 지우면 실제 노트가 지워지는 사고가 그것이다.
// 여기서 지키는 계약은 "주입 뒤에는 어떤 액션도 서버에 닿지 않는다"이다.

import { beforeEach, describe, expect, it, vi } from 'vitest'

// 서버 경로가 살아 있으면 즉시 터지게 둔다 — 조용히 성공하는 것보다 낫다.
vi.mock('../../lib/supabase', () => ({
  supabase: new Proxy(
    {},
    {
      get() {
        throw new Error('쇼케이스에서 supabase에 접근했다')
      },
    }
  ),
  uploadAttachment: () => {
    throw new Error('쇼케이스에서 uploadAttachment를 호출했다')
  },
}))

import { useNotesStore } from '../../stores/notes'
import { seedStyleguideStores } from '../seed'
import { STYLEGUIDE_NOTES, STYLEGUIDE_PROJECTS, STYLEGUIDE_TAGS } from '../fixtures'

describe('seedStyleguideStores', () => {
  beforeEach(() => {
    seedStyleguideStores()
  })

  it('노트·태그·프로젝트를 픽스처로 채운다', () => {
    const state = useNotesStore.getState()

    expect(state.notes).toHaveLength(STYLEGUIDE_NOTES.length)
    expect(state.allTags).toHaveLength(STYLEGUIDE_TAGS.length)
    expect(state.allProjects).toHaveLength(STYLEGUIDE_PROJECTS.length)
    expect(state.isLoading).toBe(false)
  })

  it('두 번 주입해도 같은 화면이다', () => {
    seedStyleguideStores()
    expect(useNotesStore.getState().notes).toHaveLength(STYLEGUIDE_NOTES.length)
  })

  // ── 서버로 나가면 안 되는 것들 ──
  // 하나라도 원본 구현이 살아 있으면 위 Proxy가 던져서 테스트가 깨진다.

  it('읽기 액션은 서버에 가지 않고 목록도 흔들지 않는다', async () => {
    const before = useNotesStore.getState().notes

    await useNotesStore.getState().loadNotes()
    await useNotesStore.getState().loadTags()
    await useNotesStore.getState().loadProjects()
    await useNotesStore.getState().loadTrash()
    await useNotesStore.getState().loadArchived()

    expect(useNotesStore.getState().notes).toBe(before)
  })

  it('쓰기 액션도 서버에 가지 않는다', async () => {
    const target = useNotesStore.getState().notes[0]

    await useNotesStore.getState().updateNote(target.id, '고친 본문')
    await useNotesStore.getState().togglePinNote(target.id)
    await useNotesStore.getState().archiveNote(target.id)
    await useNotesStore.getState().addTagToNote(target.id, '새태그')
    await useNotesStore.getState().createNote('새 노트')

    expect(useNotesStore.getState().notes).toHaveLength(STYLEGUIDE_NOTES.length)
  })

  it('파괴적 액션도 서버에 가지 않는다', async () => {
    const target = useNotesStore.getState().notes[0]

    await useNotesStore.getState().deleteNote(target.id)
    await useNotesStore.getState().permanentlyDeleteNote(target.id)
    await useNotesStore.getState().emptyTrash()

    expect(useNotesStore.getState().notes).toHaveLength(STYLEGUIDE_NOTES.length)
  })

  it('실시간 구독은 열지 않지만 해지 함수는 돌려준다', () => {
    const unsubscribe = useNotesStore.getState().subscribeToChanges()
    expect(typeof unsubscribe).toBe('function')
    expect(() => unsubscribe()).not.toThrow()
  })

  // ── 살아 있어야 하는 것들 ──
  // 전부 죽이면 쇼케이스가 정지 화면이 된다. 로컬 UI 상태는 그대로 돈다.

  it('뷰 모드·필터 같은 로컬 UI 상태는 그대로 동작한다', () => {
    useNotesStore.getState().setViewMode('archived')
    expect(useNotesStore.getState().viewMode).toBe('archived')

    useNotesStore.getState().setFilterTag('design')
    expect(useNotesStore.getState().filterTag).toBe('design')

    useNotesStore.getState().setFeedScope('inbox')
    expect(useNotesStore.getState().feedScope).toBe('inbox')
  })

  it('삭제 확인 대기 같은 로컬 전이도 그대로 동작한다', () => {
    const target = useNotesStore.getState().notes[0]

    useNotesStore.getState().requestDeleteNote(target.id)
    expect(useNotesStore.getState().pendingDeleteNoteId).toBe(target.id)

    useNotesStore.getState().cancelDeleteNote()
    expect(useNotesStore.getState().pendingDeleteNoteId).toBeNull()
  })
})
