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

  // BRU-213 — 블록 마커만 떼고 인라인 표시는 그대로 두고 있었다. 그래서 목록에서
  // `**형광펜**` 같은 글자가 별표째 보였다 — 펼치면 굵은 글씨인데 접으면 별표다.
  it('굵게 표시를 떼고 글자만 남긴다', () => {
    expect(toSingleLinePreview('강조는 **형광펜**이다')).toBe('강조는 형광펜이다')
  })

  it('강조 표시를 떼고 글자만 남긴다', () => {
    expect(toSingleLinePreview('인용은 *면 없이*')).toBe('인용은 면 없이')
  })

  it('인라인 코드의 백틱을 뗀다', () => {
    expect(toSingleLinePreview('`font: var(--type-row)` 를 쓴다')).toBe(
      'font: var(--type-row) 를 쓴다'
    )
  })

  it('링크는 보이는 글자만 남긴다 — 주소는 한 줄에서 자리만 먹는다', () => {
    expect(toSingleLinePreview('[이슈 보기](https://linear.app/x)를 눌러라')).toBe(
      '이슈 보기를 눌러라'
    )
  })

  it('코드 펜스 줄은 통째로 뺀다 — 글자가 하나도 없는 줄이다', () => {
    expect(toSingleLinePreview('설명\n```ts\nconst a = 1\n```')).toBe('설명 const a = 1')
  })

  it('밑줄은 그대로 둔다 — created_at_utc 는 강조가 아니다', () => {
    expect(toSingleLinePreview('컬럼은 created_at_utc 이다')).toBe('컬럼은 created_at_utc 이다')
  })

  it('주소만 적힌 줄은 주소를 그대로 보여 준다', () => {
    expect(toSingleLinePreview('읽을 것 — https://example.com/a')).toBe(
      '읽을 것 — https://example.com/a'
    )
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
