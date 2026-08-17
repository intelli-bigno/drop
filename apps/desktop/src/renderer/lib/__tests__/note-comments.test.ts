import { describe, it, expect } from 'vitest'
import {
  countCommentsByNote,
  sortCommentsOldestFirst,
  insertOptimisticComment,
  confirmOptimisticComment,
  rollbackOptimisticComment,
  adjustCommentCount,
  canSubmitComment,
  normalizeCommentBody,
  commentDeleteMessage,
} from '../note-comments'
import type { NoteComment } from '@drop/shared'

function comment(id: string, createdAt: string, body = id): NoteComment {
  return {
    id,
    noteId: 'note-1',
    userId: 'user-1',
    body,
    createdAt: new Date(createdAt),
    updatedAt: new Date(createdAt),
    isPending: false,
  }
}

describe('countCommentsByNote', () => {
  it('빈 목록이면 빈 집계를 준다', () => {
    expect(countCommentsByNote([])).toEqual({})
  })

  it('노트별로 행 수를 센다', () => {
    const counts = countCommentsByNote([
      { note_id: 'a' },
      { note_id: 'b' },
      { note_id: 'a' },
    ])
    expect(counts).toEqual({ a: 2, b: 1 })
  })

  it('댓글이 하나도 없는 노트는 키 자체를 만들지 않는다 — 0이면 뱃지를 안 그리기 위해', () => {
    expect(countCommentsByNote([{ note_id: 'a' }])).not.toHaveProperty('b')
  })
})

describe('sortCommentsOldestFirst', () => {
  it('오래된 댓글이 위로 온다 — 대화는 위에서 아래로 읽힌다', () => {
    const sorted = sortCommentsOldestFirst([
      comment('c', '2026-08-17T03:00:00Z'),
      comment('a', '2026-08-17T01:00:00Z'),
      comment('b', '2026-08-17T02:00:00Z'),
    ])
    expect(sorted.map((c) => c.id)).toEqual(['a', 'b', 'c'])
  })

  it('원본 배열을 건드리지 않는다', () => {
    const input = [comment('b', '2026-08-17T02:00:00Z'), comment('a', '2026-08-17T01:00:00Z')]
    sortCommentsOldestFirst(input)
    expect(input.map((c) => c.id)).toEqual(['b', 'a'])
  })
})

describe('낙관적 삽입 상태 전이', () => {
  const existing = [comment('a', '2026-08-17T01:00:00Z')]
  const optimistic = { ...comment('tmp', '2026-08-17T02:00:00Z', '새 댓글'), isPending: true }

  it('낙관적 댓글은 맨 뒤에 붙고 pending 표시가 남는다', () => {
    const next = insertOptimisticComment(existing, optimistic)
    expect(next.map((c) => c.id)).toEqual(['a', 'tmp'])
    expect(next[1].isPending).toBe(true)
    expect(existing).toHaveLength(1)
  })

  it('서버 응답이 오면 같은 자리에서 실제 댓글로 교체되고 pending이 풀린다', () => {
    const inserted = insertOptimisticComment(existing, optimistic)
    const saved = comment('real', '2026-08-17T02:00:01Z', '새 댓글')
    const next = confirmOptimisticComment(inserted, 'tmp', saved)
    expect(next.map((c) => c.id)).toEqual(['a', 'real'])
    expect(next[1].isPending).toBe(false)
  })

  it('실패하면 낙관적 댓글만 걷어낸다 — 나머지는 그대로다', () => {
    const inserted = insertOptimisticComment(existing, optimistic)
    const next = rollbackOptimisticComment(inserted, 'tmp')
    expect(next.map((c) => c.id)).toEqual(['a'])
  })

  it('모르는 id로 롤백해도 목록이 망가지지 않는다', () => {
    expect(rollbackOptimisticComment(existing, 'nope').map((c) => c.id)).toEqual(['a'])
  })
})

describe('adjustCommentCount', () => {
  it('없던 노트에 +1이면 1이 된다', () => {
    expect(adjustCommentCount({}, 'a', 1)).toEqual({ a: 1 })
  })

  it('기존 값을 증감한다', () => {
    expect(adjustCommentCount({ a: 2 }, 'a', -1)).toEqual({ a: 1 })
  })

  it('0이 되면 키를 지운다 — 0짜리 뱃지가 남지 않게', () => {
    expect(adjustCommentCount({ a: 1, b: 3 }, 'a', -1)).toEqual({ b: 3 })
  })

  it('음수로 내려가지 않는다', () => {
    expect(adjustCommentCount({ a: 1 }, 'a', -5)).toEqual({})
  })

  it('원본을 건드리지 않는다', () => {
    const counts = { a: 1 }
    adjustCommentCount(counts, 'a', 1)
    expect(counts).toEqual({ a: 1 })
  })
})

describe('canSubmitComment', () => {
  it('공백뿐이면 보낼 수 없다', () => {
    expect(canSubmitComment('   \n ')).toBe(false)
    expect(canSubmitComment('')).toBe(false)
  })

  it('내용이 있으면 보낼 수 있다', () => {
    expect(canSubmitComment(' 안녕 ')).toBe(true)
  })
})

describe('normalizeCommentBody', () => {
  it('앞뒤 공백을 떼어낸다', () => {
    expect(normalizeCommentBody('  댓글  ')).toBe('댓글')
  })
})

describe('commentDeleteMessage', () => {
  it('지울 댓글이 무엇인지 본문을 인용한다', () => {
    expect(commentDeleteMessage('짧은 댓글')).toContain('짧은 댓글')
  })

  it('긴 본문은 한 줄로 줄여 인용한다', () => {
    const message = commentDeleteMessage(`${'가'.repeat(200)}`)
    expect(message).toContain('…')
    expect(message.length).toBeLessThan(200)
  })

  it('줄바꿈은 한 줄로 접는다', () => {
    expect(commentDeleteMessage('첫 줄\n둘째 줄')).toContain('첫 줄 둘째 줄')
  })
})
