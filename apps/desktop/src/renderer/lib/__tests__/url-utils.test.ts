import { describe, it, expect } from 'vitest'
import { hasUrlInText, extractUrls } from '../url-utils'

describe('hasUrlInText', () => {
  it('detects a bare URL', () => {
    expect(hasUrlInText('https://work-salon.pages.dev/')).toBe(true)
  })

  it('detects a URL that is not on the first line', () => {
    expect(
      hasUrlInText(
        '[네이버지도]\n갓잇 하남미사점\n경기 하남시 미사강변중앙로 193\nhttps://naver.me/GT4UKu03'
      )
    ).toBe(true)
  })

  it('detects a URL that contains escaped underscores (markdown-escaped)', () => {
    expect(hasUrlInText('https://claude.ai/code/artifact/e710516f?via=auto\\_preview')).toBe(true)
  })

  // BRU-67: URL_REGEX가 /g 플래그를 가진 모듈 공유 객체라 .test()가 lastIndex를
  // 남긴다. 그래서 URL이 있는 노트를 연속으로 검사하면 하나 걸러 하나씩 false가 됐다.
  it('is not stateful across consecutive calls', () => {
    const urls = [
      'https://work-salon.pages.dev/',
      'https://contentsalon.pages.dev/coaching',
      'https://naver.me/GT4UKu03',
      'https://naver.me/GQGsHCAs',
      'https://web.plaud.ai/s/pub_efb75d5f',
    ]
    expect(urls.map((u) => hasUrlInText(u))).toEqual([true, true, true, true, true])
  })

  it('returns false when there is no URL', () => {
    expect(hasUrlInText('그냥 메모 한 줄')).toBe(false)
    expect(hasUrlInText('')).toBe(false)
  })
})

describe('extractUrls', () => {
  it('is not stateful across consecutive calls', () => {
    const a = extractUrls('https://a.example/one')
    const b = extractUrls('https://b.example/two')
    expect(a).toEqual(['https://a.example/one'])
    expect(b).toEqual(['https://b.example/two'])
  })
})
