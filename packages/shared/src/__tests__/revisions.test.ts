import { describe, it, expect } from 'vitest'
import { noteRevisionRowToNoteRevision, summarizeRevision } from '../revisions'
import type { NoteRevisionRow } from '../revisions'

const row: NoteRevisionRow = {
  id: 'rev-1',
  note_id: 'note-1',
  content: '이전 내용',
  created_at: '2026-08-11T10:00:00.000Z',
}

describe('noteRevisionRowToNoteRevision', () => {
  it('shouldMapSnakeCaseRowToCamelCase', () => {
    const revision = noteRevisionRowToNoteRevision(row)
    expect(revision.id).toBe('rev-1')
    expect(revision.noteId).toBe('note-1')
    expect(revision.content).toBe('이전 내용')
  })

  it('shouldParseCreatedAtIntoDate', () => {
    const revision = noteRevisionRowToNoteRevision(row)
    expect(revision.createdAt).toBeInstanceOf(Date)
    expect(revision.createdAt.toISOString()).toBe('2026-08-11T10:00:00.000Z')
  })
})

describe('summarizeRevision', () => {
  it('shouldReturnContentUnchangedWhenShort', () => {
    expect(summarizeRevision('짧은 내용')).toBe('짧은 내용')
  })

  it('shouldCollapseNewlinesIntoSpaces', () => {
    expect(summarizeRevision('첫 줄\n둘째 줄')).toBe('첫 줄 둘째 줄')
  })

  it('shouldTrimSurroundingWhitespace', () => {
    expect(summarizeRevision('  내용  ')).toBe('내용')
  })

  it('shouldTruncateLongContentWithEllipsis', () => {
    const long = 'a'.repeat(200)
    const summary = summarizeRevision(long)
    expect(summary.length).toBe(121) // 120자 + …
    expect(summary.endsWith('…')).toBe(true)
  })

  it('shouldDescribeEmptyContent', () => {
    expect(summarizeRevision('')).toBe('(빈 노트)')
    expect(summarizeRevision('   ')).toBe('(빈 노트)')
  })
})
