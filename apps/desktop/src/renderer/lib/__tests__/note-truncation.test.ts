import { describe, it, expect } from 'vitest'
import { shouldTruncateNote, COLLAPSED_LINE_LIMIT } from '../note-truncation'

describe('shouldTruncateNote', () => {
  it('shouldKeepOneLineNoteExpanded', () => {
    expect(shouldTruncateNote('짧은 메모')).toBe(false)
  })

  it('shouldKeepTwoLineNoteExpanded', () => {
    // 기본 노출 줄 수까지는 접지 않는다
    expect(shouldTruncateNote('첫 줄\n둘째 줄')).toBe(false)
  })

  it('shouldTruncateFromTheThirdLine', () => {
    expect(shouldTruncateNote('첫 줄\n둘째 줄\n셋째 줄')).toBe(true)
  })

  it('shouldTruncateLongSingleLine', () => {
    expect(shouldTruncateNote('a'.repeat(200))).toBe(true)
  })

  it('shouldNotTruncateShortSingleLine', () => {
    expect(shouldTruncateNote('a'.repeat(80))).toBe(false)
  })

  it('shouldHandleEmptyContent', () => {
    expect(shouldTruncateNote('')).toBe(false)
  })

  it('shouldExposeTheLineLimitUsedByCss', () => {
    // CSS의 접힘 높이와 같은 값을 봐야 한다 — 어긋나면 잘림 위치가 안 맞는다
    expect(COLLAPSED_LINE_LIMIT).toBe(2)
  })
})
