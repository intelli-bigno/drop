// 쇼케이스용 스토어 주입 (BRU-172).
//
// 쇼케이스는 실물 컴포넌트를 렌더하므로 실물 스토어를 그대로 쓴다. 그래서 딱 하나를
// 확실히 막아야 한다 — **화면 안에서 누른 것이 서버로 나가는 것.**
// 쇼케이스에서 노트를 지웠는데 진짜 노트가 사라지면 그건 쇼케이스가 아니라 사고다.
//
// 방식: 서버에 닿는 액션은 전부 무해한 껍데기로 갈아 끼우고, 로컬 UI 상태만 만지는
// 액션은 원본 그대로 둔다. 후자를 같이 죽이면 화면이 정지 그림이 되어 버린다.

import type { User } from '@supabase/supabase-js'
import { useNotesStore } from '../stores/notes'
import { useAuthStore } from '../stores/auth'
import { useProfileStore } from '../stores/profile'
import {
  STYLEGUIDE_ARCHIVED,
  STYLEGUIDE_COMMENTS,
  STYLEGUIDE_COMMENT_COUNTS,
  STYLEGUIDE_NOTES,
  STYLEGUIDE_PROJECTS,
  STYLEGUIDE_TAGS,
  STYLEGUIDE_TRASHED,
} from './fixtures'

/**
 * 원본 구현을 살려 둘 액션들 — 전부 로컬 상태 전이라 서버에 닿지 않는다.
 * 여기 없는 액션은 무해한 껍데기로 교체된다. 새 액션이 슬라이스에 생기면
 * 기본값이 "막는다"가 되도록 화이트리스트로 둔 것이다.
 */
const LOCAL_ONLY_ACTIONS = new Set<string>([
  'selectNote',
  'requestDeleteNote',
  'cancelDeleteNote',
  'openHistory',
  'closeHistory',
  'openComments',
  'closeComments',
  'requestDeleteComment',
  'cancelDeleteComment',
  'setFilterTag',
  'setFilterProject',
  'setCategoryFilter',
  'setFeedScope',
  'setShowExported',
  'setViewMode',
  'temporarilyUnlockNote',
  'relockNote',
  'temporarilyUnlockAll',
  'relockAll',
  'hasLockedNotes',
])

/** 무엇을 돌려줘야 호출한 쪽이 안 터지는지가 액션마다 다르다. */
function neutralize(name: string): (...args: unknown[]) => unknown {
  // 구독 해지 함수를 기대하는 자리 — cleanup에서 그대로 호출된다.
  if (name === 'subscribeToChanges') return () => () => {}
  // 노트를 돌려주기로 한 자리 — null이면 호출부가 "실패"로 읽고 토스트를 띄운다.
  if (name === 'createNote') return async () => STYLEGUIDE_NOTES[0]
  if (name === 'createProject') return async () => STYLEGUIDE_PROJECTS[0]
  if (name === 'addAttachment' || name.startsWith('createNoteWith')) return async () => null
  return async () => undefined
}

/** 서버에 닿는 액션을 전부 껍데기로 바꾼 상태 조각을 만든다. */
function neutralizedActions(state: Record<string, unknown>): Record<string, unknown> {
  const patch: Record<string, unknown> = {}
  for (const [key, value] of Object.entries(state)) {
    if (typeof value !== 'function') continue
    if (LOCAL_ONLY_ACTIONS.has(key)) continue
    patch[key] = neutralize(key)
  }
  return patch
}

/** 쇼케이스는 로그인 화면을 지나지 않는다 — 최소한의 사용자 자리만 채운다. */
const STYLEGUIDE_USER = {
  id: 'sg-user',
  email: 'showcase@drop.local',
  user_metadata: { full_name: '쇼케이스', avatar_url: null },
  app_metadata: {},
  aud: 'authenticated',
  created_at: '2026-01-01T00:00:00.000Z',
} as unknown as User

let neutralized = false

/**
 * 픽스처를 스토어에 붓고 서버 경로를 막는다. 여러 번 불러도 같은 화면이 된다.
 */
export function seedStyleguideStores(): void {
  const state = useNotesStore.getState() as unknown as Record<string, unknown>

  // 액션 교체는 한 번이면 된다 — 이미 껍데기인 것을 다시 감쌀 이유가 없다.
  const actionPatch = neutralized ? {} : neutralizedActions(state)
  neutralized = true

  useNotesStore.setState({
    ...actionPatch,
    notes: [...STYLEGUIDE_NOTES],
    trashedNotes: [...STYLEGUIDE_TRASHED],
    archivedNotes: [...STYLEGUIDE_ARCHIVED],
    allTags: [...STYLEGUIDE_TAGS],
    allProjects: [...STYLEGUIDE_PROJECTS],
    commentsByNote: { ...groupComments() },
    commentCountByNote: { ...STYLEGUIDE_COMMENT_COUNTS },
    isLoading: false,
    isCommentsLoading: false,
    isRevisionsLoading: false,
    selectedNoteId: null,
    pendingDeleteNoteId: null,
    pendingDeleteCommentId: null,
    commentsNoteId: null,
    historyNoteId: null,
    viewMode: 'active',
    filterTag: null,
    filterProjectId: null,
    categoryFilter: null,
    feedScope: null,
    showExported: false,
    temporarilyUnlockedNoteIds: new Set<string>(),
  } as never)

  useAuthStore.setState({
    user: STYLEGUIDE_USER,
    session: null,
    isAuthLoading: false,
    initializeAuth: async () => {},
    signInWithGoogle: async () => {},
    signOut: async () => {},
  })

  useProfileStore.setState({
    hasPin: true,
    isLoading: false,
    loadProfile: async () => {},
    setPin: async () => {},
    verifyPin: async (pin: string) => pin === '0000',
    removePin: async () => {},
  })
}

function groupComments(): Record<string, typeof STYLEGUIDE_COMMENTS> {
  const grouped: Record<string, typeof STYLEGUIDE_COMMENTS> = {}
  for (const comment of STYLEGUIDE_COMMENTS) {
    grouped[comment.noteId] = [...(grouped[comment.noteId] ?? []), comment]
  }
  return grouped
}
