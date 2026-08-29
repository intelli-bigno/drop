// 쇼케이스가 쓰는 고정 데이터 (BRU-172).
//
// 순수 데이터다 — 스토어도 Supabase도 여기서 건드리지 않는다. 주입은 seed.ts가 한다.
// 시간을 고정하는 이유: 쇼케이스는 회귀를 눈으로 잡는 화면이라 어제와 오늘이 같아야 한다.
// "3분 전"이 매번 달라지면 무엇이 바뀐 건지 알 수 없다.

import type { Attachment, Note, Tag } from '@drop/shared'
import type { NoteComment } from '@drop/shared'
import type { Project } from '@drop/shared'

/** 쇼케이스의 '지금'. 상대 시간 표기가 매 렌더 흔들리지 않게 못 박는다. */
export const STYLEGUIDE_NOW = new Date('2026-08-29T09:00:00+09:00')

function minutesAgo(minutes: number): Date {
  return new Date(STYLEGUIDE_NOW.getTime() - minutes * 60_000)
}

let sequence = 0
function nextId(prefix: string): string {
  sequence += 1
  return `sg-${prefix}-${sequence}`
}

export function makeNote(overrides: Partial<Note> = {}): Note {
  return {
    id: nextId('note'),
    displayId: 1000 + sequence,
    content: '',
    parentId: null,
    attachments: [],
    tags: [],
    createdAt: minutesAgo(30),
    updatedAt: minutesAgo(30),
    source: 'desktop',
    isDeleted: false,
    hasLink: false,
    hasMedia: false,
    hasFiles: false,
    isLocked: false,
    deletedAt: null,
    archivedAt: null,
    priority: 0,
    isPinned: false,
    pinnedAt: null,
    linearIssueUrl: null,
    linearIssueKey: null,
    linearExportedAt: null,
    projectId: null,
    // 기본은 일반 노트 — 할일 쇼케이스는 overrides로 type을 넘긴다 (BRU-175)
    type: 'note',
    completedAt: null,
    ...overrides,
  }
}

// ── 태그 ────────────────────────────────────────────────────────────

function makeTag(id: string, name: string): Tag {
  return { id, name, createdAt: minutesAgo(6000), lastUsedAt: minutesAgo(60) }
}

export const STYLEGUIDE_TAGS: Tag[] = [
  makeTag('sg-tag-design', 'design'),
  makeTag('sg-tag-infra', 'infra'),
  makeTag('sg-tag-a11y', 'a11y'),
  makeTag('sg-tag-읽을거리', '읽을거리'),
  makeTag('sg-tag-회고', '회고'),
]

const [TAG_DESIGN, TAG_INFRA, TAG_A11Y, TAG_READING] = STYLEGUIDE_TAGS

// ── 프로젝트 ─────────────────────────────────────────────────────────

function makeProject(id: string, name: string, color: string | null): Project {
  return {
    id,
    name,
    color,
    description: null,
    archivedAt: null,
    createdAt: minutesAgo(20000),
    updatedAt: minutesAgo(200),
  }
}

export const STYLEGUIDE_PROJECTS: Project[] = [
  makeProject('sg-proj-drop', 'DROP', '#d9730d'),
  makeProject('sg-proj-infra', '머신 정비', '#6b7280'),
]

const [PROJECT_DROP] = STYLEGUIDE_PROJECTS

// ── 첨부 ────────────────────────────────────────────────────────────

function makeAttachment(noteId: string, overrides: Partial<Attachment> = {}): Attachment {
  return {
    id: nextId('att'),
    noteId,
    type: 'file',
    storagePath: 'styleguide/placeholder.pdf',
    filename: '팔레트-대비-실측.pdf',
    mimeType: 'application/pdf',
    size: 184_320,
    createdAt: minutesAgo(120),
    ...overrides,
  }
}

// ── 노트 ────────────────────────────────────────────────────────────
//
// 여기 담긴 상태 집합이 곧 쇼케이스가 보여주겠다고 약속한 목록이다.
// 하나 빼면 __tests__/fixtures.test.ts가 잡는다.

const PARENT = makeNote({
  content: 'UI 킷 후보를 넷으로 좁혔다 — 현행+Radix / shadcn / Radix Themes / Mantine',
  tags: [TAG_DESIGN],
  projectId: PROJECT_DROP.id,
  createdAt: minutesAgo(12),
  updatedAt: minutesAgo(12),
})

const PINNED = makeNote({
  content: '오늘 결정할 것 — 밀도를 현행 4px로 지킬지, Things 리듬으로 풀지',
  isPinned: true,
  pinnedAt: minutesAgo(5),
  priority: 2,
  tags: [TAG_DESIGN],
  projectId: PROJECT_DROP.id,
  createdAt: minutesAgo(45),
  updatedAt: minutesAgo(5),
})

export const STYLEGUIDE_NOTES: Note[] = [
  PINNED,
  PARENT,
  makeNote({
    // 화살표 같은 글자를 넣지 않는다 — 계층은 앱이 그리는 것이지 본문에 적는 것이 아니다.
    // 여기 '↳'를 박아 두었더니 쇼케이스가 "앱이 가지를 그린다"고 거짓말을 했다 (BRU-187).
    content: 'Radix는 CSS를 한 줄도 안 들고 온다. "킷을 쓴다"에 해당하지 않는 이유.',
    parentId: PARENT.id,
    createdAt: minutesAgo(10),
    updatedAt: minutesAgo(10),
  }),
  makeNote({
    content: '액센트 위 흰 글자 대비 실측 — 라이트 3.3:1, 다크 2.2:1. 어두운 글자로 간다.',
    tags: [TAG_A11Y, TAG_DESIGN],
    priority: 3,
    attachments: [],
    projectId: PROJECT_DROP.id,
    createdAt: minutesAgo(90),
    updatedAt: minutesAgo(88),
  }),
  makeNote({
    content: 'UserMenu가 아직 다크 단일 모드 시절 하드코딩 색을 쓰고 있다 — 라이트에서 흰 글자',
    tags: [TAG_DESIGN],
    linearIssueUrl: 'https://linear.app/intellieffect/issue/BRU-173',
    linearIssueKey: 'BRU-173',
    linearExportedAt: minutesAgo(20),
    projectId: PROJECT_DROP.id,
    createdAt: minutesAgo(140),
    updatedAt: minutesAgo(140),
  }),
  makeNote({
    content: 'tg.db 정본을 Mini로 옮기기 전에 수집 데몬 중복 기동부터 막을 것',
    tags: [TAG_INFRA],
    projectId: STYLEGUIDE_PROJECTS[1].id,
    createdAt: minutesAgo(300),
    updatedAt: minutesAgo(300),
  }),
  makeNote({
    content: '읽을 것 — https://www.nngroup.com/articles/ui-density/ 밀도와 스캔 속도',
    hasLink: true,
    tags: [TAG_READING],
    createdAt: minutesAgo(420),
    updatedAt: minutesAgo(420),
  }),
  makeNote({
    content: '금고 비밀번호와 계좌 메모',
    isLocked: true,
    createdAt: minutesAgo(1500),
    updatedAt: minutesAgo(1500),
  }),
  makeNote({
    content: '토큰 대비 미달 3건 고치기 — BRU-177',
    type: 'todo',
    completedAt: null,
    tags: [TAG_DESIGN],
    projectId: PROJECT_DROP.id,
    createdAt: minutesAgo(60),
    updatedAt: minutesAgo(60),
  }),
  makeNote({
    content: '쇼케이스 라우트 올리기',
    type: 'todo',
    completedAt: minutesAgo(15),
    projectId: PROJECT_DROP.id,
    createdAt: minutesAgo(180),
    updatedAt: minutesAgo(15),
  }),
  makeNote({
    content: '',
    createdAt: minutesAgo(2),
    updatedAt: minutesAgo(2),
  }),
]

// 첨부는 노트 id가 정해진 뒤에 매단다.
const NOTE_WITH_FILE = STYLEGUIDE_NOTES[3]
NOTE_WITH_FILE.attachments = [makeAttachment(NOTE_WITH_FILE.id)]
NOTE_WITH_FILE.hasFiles = true

export const STYLEGUIDE_ARCHIVED: Note[] = [
  makeNote({
    content: '2026 상반기 회고 — 3중 구현 유지비를 과소평가했다',
    archivedAt: minutesAgo(4000),
    createdAt: minutesAgo(20000),
    updatedAt: minutesAgo(4000),
  }),
]

export const STYLEGUIDE_TRASHED: Note[] = [
  makeNote({
    content: '잘못 붙여넣은 URL',
    isDeleted: true,
    deletedAt: minutesAgo(600),
    createdAt: minutesAgo(700),
    updatedAt: minutesAgo(600),
  }),
]

// ── 댓글 ────────────────────────────────────────────────────────────

export const STYLEGUIDE_COMMENTS: NoteComment[] = [
  {
    id: 'sg-comment-1',
    noteId: PARENT.id,
    userId: 'sg-user',
    body: '밀도는 시착실 05번 표본 보고 정하자.',
    createdAt: minutesAgo(8),
    updatedAt: minutesAgo(8),
    isPending: false,
  },
  {
    id: 'sg-comment-2',
    noteId: PARENT.id,
    userId: 'sg-user',
    body: '보내는 중…',
    createdAt: minutesAgo(1),
    updatedAt: minutesAgo(1),
    isPending: true,
  },
]

export const STYLEGUIDE_COMMENT_COUNTS: Record<string, number> = {
  [PARENT.id]: STYLEGUIDE_COMMENTS.length,
}
