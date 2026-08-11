import { describe, it, expect } from 'vitest'
import { buildDeleteConfirmMessage } from '../delete-confirm'

describe('buildDeleteConfirmMessage', () => {
  it('shouldQuoteShortContentAsIs', () => {
    expect(buildDeleteConfirmMessage({ content: '장보기 목록', attachmentCount: 0 })).toBe(
      '"장보기 목록"\n\n휴지통으로 이동합니다.'
    )
  })

  it('shouldCollapseNewlinesSoTheDialogStaysOneLine', () => {
    expect(buildDeleteConfirmMessage({ content: '첫 줄\n둘째 줄', attachmentCount: 0 })).toContain(
      '"첫 줄 둘째 줄"'
    )
  })

  it('shouldTruncateLongContent', () => {
    const message = buildDeleteConfirmMessage({ content: 'a'.repeat(200), attachmentCount: 0 })
    expect(message).toContain('…')
    expect(message.split('\n')[0].length).toBeLessThan(90)
  })

  it('shouldDescribeEmptyNote', () => {
    expect(buildDeleteConfirmMessage({ content: '', attachmentCount: 0 })).toContain('빈 노트')
    expect(buildDeleteConfirmMessage({ content: '   ', attachmentCount: 0 })).toContain('빈 노트')
  })

  // 첨부가 있는 노트는 잃는 것이 더 크다 — 확인 문구에서 드러나야 한다
  it('shouldMentionAttachmentCount', () => {
    expect(buildDeleteConfirmMessage({ content: '사진 모음', attachmentCount: 3 })).toContain(
      '첨부 3개'
    )
  })

  it('shouldNotMentionAttachmentsWhenThereAreNone', () => {
    expect(buildDeleteConfirmMessage({ content: '메모', attachmentCount: 0 })).not.toContain('첨부')
  })

  it('shouldAlwaysSayWhereTheNoteGoes', () => {
    expect(buildDeleteConfirmMessage({ content: '메모', attachmentCount: 0 })).toContain(
      '휴지통으로 이동'
    )
  })
})
