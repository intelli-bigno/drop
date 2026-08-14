import { describe, it, expect } from 'vitest'
import { toSingleLinePreview, countContentLinks } from '../note-line'

describe('toSingleLinePreview', () => {
  it('should return an empty string for empty content', () => {
    expect(toSingleLinePreview('')).toBe('')
  })

  it('should keep a short single line as it is', () => {
    expect(toSingleLinePreview('짧은 메모')).toBe('짧은 메모')
  })

  it('should join multiple lines into one line', () => {
    expect(toSingleLinePreview('첫 줄\n둘째 줄')).toBe('첫 줄 둘째 줄')
  })

  it('should collapse blank lines and repeated spaces into a single space', () => {
    expect(toSingleLinePreview('첫 줄\n\n\n둘째   줄')).toBe('첫 줄 둘째 줄')
  })

  it('should trim leading and trailing whitespace', () => {
    expect(toSingleLinePreview('  가운데  \n')).toBe('가운데')
  })

  it('should drop markdown heading markers', () => {
    expect(toSingleLinePreview('## 제목\n본문')).toBe('제목 본문')
  })

  it('should drop markdown bullet markers', () => {
    expect(toSingleLinePreview('- 하나\n- 둘')).toBe('하나 둘')
  })

  it('should drop markdown ordered list markers', () => {
    expect(toSingleLinePreview('1. 하나\n2. 둘')).toBe('하나 둘')
  })

  it('should drop blockquote markers', () => {
    expect(toSingleLinePreview('> 인용문')).toBe('인용문')
  })

  it('should keep a hyphen that is part of a word', () => {
    expect(toSingleLinePreview('e-mail 확인')).toBe('e-mail 확인')
  })

  it('should return an empty string when content is whitespace only', () => {
    expect(toSingleLinePreview('   \n\n  ')).toBe('')
  })
})

describe('countContentLinks', () => {
  it('should count no links in plain text', () => {
    expect(countContentLinks('링크 없는 메모')).toBe(0)
  })

  it('should count a single link', () => {
    expect(countContentLinks('참고 https://example.com 확인')).toBe(1)
  })

  it('should count distinct links separately', () => {
    expect(countContentLinks('https://a.com 그리고 https://b.com')).toBe(2)
  })

  it('should count a repeated link only once', () => {
    expect(countContentLinks('https://a.com https://a.com')).toBe(1)
  })

  it('should count no links in empty content', () => {
    expect(countContentLinks('')).toBe(0)
  })
})
