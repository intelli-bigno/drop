// 쇼케이스 픽스처 (BRU-172).
//
// 쇼케이스는 "이 앱에 어떤 상태가 있는가"를 보여주겠다고 약속하는 화면이다.
// 그 약속이 조용히 깨지는 경로가 하나 있다 — 픽스처에서 상태가 빠지는 것.
// 화면은 멀쩡히 뜨고, 그냥 그 상태만 안 보인다. 여기서 그걸 막는다.

import { describe, expect, it } from 'vitest'
import {
  makeNote,
  STYLEGUIDE_NOTES,
  STYLEGUIDE_TAGS,
  STYLEGUIDE_PROJECTS,
  STYLEGUIDE_COMMENTS,
} from '../fixtures'

describe('makeNote', () => {
  it('넘기지 않은 필드를 전부 기본값으로 채운다', () => {
    const note = makeNote()

    // Note 타입의 필수 필드가 하나라도 undefined면 컴포넌트가 렌더 중에 터진다.
    const required = [
      'id',
      'displayId',
      'content',
      'parentId',
      'attachments',
      'tags',
      'createdAt',
      'updatedAt',
      'source',
      'isDeleted',
      'hasLink',
      'hasMedia',
      'hasFiles',
      'isLocked',
      'deletedAt',
      'archivedAt',
      'priority',
      'isPinned',
      'pinnedAt',
      'linearIssueUrl',
      'linearIssueKey',
      'linearExportedAt',
      'projectId',
      'type',
      'completedAt',
    ] as const

    for (const key of required) {
      expect(note, `${key}가 비어 있다`).toHaveProperty(key)
      expect(note[key], `${key}가 undefined다`).not.toBeUndefined()
    }
  })

  it('넘긴 값은 기본값을 덮는다', () => {
    const note = makeNote({ content: '덮어쓴 본문', isPinned: true, priority: 2 })

    expect(note.content).toBe('덮어쓴 본문')
    expect(note.isPinned).toBe(true)
    expect(note.priority).toBe(2)
  })

  it('부를 때마다 다른 id를 준다', () => {
    expect(makeNote().id).not.toBe(makeNote().id)
  })

  it('시간을 고정한다 — 쇼케이스는 매번 같은 화면이어야 한다', () => {
    expect(makeNote().createdAt.getTime()).toBe(makeNote().createdAt.getTime())
  })
})

describe('STYLEGUIDE_NOTES', () => {
  it('id가 서로 겹치지 않는다', () => {
    const ids = STYLEGUIDE_NOTES.map((n) => n.id)
    expect(new Set(ids).size).toBe(ids.length)
  })

  // 쇼케이스가 "노트 행의 모든 상태"라고 적어 놓은 것들.
  // 픽스처에서 빠지면 그 섹션이 조용히 빈다.
  it.each([
    ['상단 고정', (n: (typeof STYLEGUIDE_NOTES)[number]) => n.isPinned],
    ['잠김', (n: (typeof STYLEGUIDE_NOTES)[number]) => n.isLocked],
    ['Linear 반출', (n: (typeof STYLEGUIDE_NOTES)[number]) => n.linearIssueUrl !== null],
    ['우선순위 지정', (n: (typeof STYLEGUIDE_NOTES)[number]) => n.priority > 0],
    ['첨부 있음', (n: (typeof STYLEGUIDE_NOTES)[number]) => n.attachments.length > 0],
    ['태그 있음', (n: (typeof STYLEGUIDE_NOTES)[number]) => n.tags.length > 0],
    ['프로젝트 지정', (n: (typeof STYLEGUIDE_NOTES)[number]) => n.projectId !== null],
    ['자식 노트', (n: (typeof STYLEGUIDE_NOTES)[number]) => n.parentId !== null],
    ['링크 포함', (n: (typeof STYLEGUIDE_NOTES)[number]) => n.hasLink],
    ['빈 본문', (n: (typeof STYLEGUIDE_NOTES)[number]) => n.content.trim() === ''],
    ['할일 (미완료)', (n: (typeof STYLEGUIDE_NOTES)[number]) => n.type === 'todo' && n.completedAt === null],
    ['할일 (완료)', (n: (typeof STYLEGUIDE_NOTES)[number]) => n.type === 'todo' && n.completedAt !== null],
    // BRU-213 — 펼친 본문이 제목·목록·인용·강조·코드를 어떻게 그리는지가
    // 이번 개편에서 가장 많이 바뀐 자리다. 표본이 없으면 쇼케이스가 그걸 못 보여준다.
    ['마크다운 본문', (n: (typeof STYLEGUIDE_NOTES)[number]) => n.content.includes('\n')],
  ])('%s 노트를 하나 이상 담고 있다', (_label, predicate) => {
    expect(STYLEGUIDE_NOTES.some(predicate)).toBe(true)
  })

  it('자식 노트의 부모가 같은 목록 안에 있다', () => {
    const ids = new Set(STYLEGUIDE_NOTES.map((n) => n.id))
    for (const note of STYLEGUIDE_NOTES) {
      if (note.parentId === null) continue
      expect(ids.has(note.parentId), `${note.id}의 부모가 목록에 없다`).toBe(true)
    }
  })

  it('노트가 참조하는 프로젝트가 실제로 존재한다', () => {
    const projectIds = new Set(STYLEGUIDE_PROJECTS.map((p) => p.id))
    for (const note of STYLEGUIDE_NOTES) {
      if (note.projectId === null) continue
      expect(projectIds.has(note.projectId), `${note.id}의 프로젝트가 없다`).toBe(true)
    }
  })

  it('노트에 달린 태그가 태그 목록에도 있다 — 태그 관리 화면과 어긋나지 않게', () => {
    const tagIds = new Set(STYLEGUIDE_TAGS.map((t) => t.id))
    for (const note of STYLEGUIDE_NOTES) {
      for (const tag of note.tags) {
        expect(tagIds.has(tag.id), `${tag.name}이 태그 목록에 없다`).toBe(true)
      }
    }
  })
})

describe('STYLEGUIDE_COMMENTS', () => {
  it('댓글이 실재하는 노트에 달려 있다', () => {
    const ids = new Set(STYLEGUIDE_NOTES.map((n) => n.id))
    expect(STYLEGUIDE_COMMENTS.length).toBeGreaterThan(0)
    for (const comment of STYLEGUIDE_COMMENTS) {
      expect(ids.has(comment.noteId), `${comment.id}의 노트가 없다`).toBe(true)
    }
  })
})
