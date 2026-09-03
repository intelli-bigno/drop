import { describe, it, expect } from 'vitest'
import { normalizeLinkInput, resolveLinkAction } from '../link-shortcut'

describe('resolveLinkAction', () => {
  it('이미 링크면 푼다 — ⌘K는 어디서나 켜고 끄는 글쇠다', () => {
    expect(
      resolveLinkAction({ selectedText: '문서', clipboardText: 'https://a.com', isLink: true })
    ).toEqual({ type: 'unlink' })
  })

  it('고른 글자가 그 자체로 주소면 그 주소로 건다 — 붙여넣을 것을 따로 찾을 이유가 없다', () => {
    expect(
      resolveLinkAction({ selectedText: 'https://drop.app/a', clipboardText: '', isLink: false })
    ).toEqual({ type: 'link', url: 'https://drop.app/a' })
  })

  it('고른 글자에 클립보드의 주소를 건다 — 주소를 복사하고 글자를 고르는 것이 실제 손버릇이다', () => {
    expect(
      resolveLinkAction({ selectedText: '회의록', clipboardText: 'https://a.com/x', isLink: false })
    ).toEqual({ type: 'link', url: 'https://a.com/x' })
  })

  it('클립보드에 딸린 말이 섞여 있어도 주소만 뽑아 쓴다', () => {
    expect(
      resolveLinkAction({
        selectedText: '회의록',
        clipboardText: '여기 봐 https://a.com/x 고마워',
        isLink: false,
      })
    ).toEqual({ type: 'link', url: 'https://a.com/x' })
  })

  it('고른 글자가 없으면 주소를 그대로 넣고 링크로 만든다', () => {
    expect(
      resolveLinkAction({ selectedText: '', clipboardText: 'https://a.com', isLink: false })
    ).toEqual({ type: 'insert', url: 'https://a.com' })
  })

  it('고른 글자 **속에** 주소가 섞여 있는 것은 다르다 — 클립보드 쪽을 쓴다', () => {
    expect(
      resolveLinkAction({
        selectedText: '자세한 건 https://a.com 참고',
        clipboardText: 'https://b.com',
        isLink: false,
      })
    ).toEqual({ type: 'link', url: 'https://b.com' })
  })

  it('걸 주소가 없으면 아무것도 하지 않는다 — 빈 링크를 만들어 두면 그게 더 나쁘다', () => {
    expect(
      resolveLinkAction({ selectedText: '회의록', clipboardText: '주소 아님', isLink: false })
    ).toEqual({ type: 'none' })
    expect(resolveLinkAction({ selectedText: '', clipboardText: '', isLink: false })).toEqual({
      type: 'none',
    })
  })

  it('www로 시작하는 주소에는 스킴을 붙인다 — 붙이지 않으면 앱 안의 상대 경로로 열린다', () => {
    expect(
      resolveLinkAction({ selectedText: '문서', clipboardText: 'www.a.com/b', isLink: false })
    ).toEqual({ type: 'link', url: 'https://www.a.com/b' })
  })
})

describe('normalizeLinkInput', () => {
  it('스킴이 없으면 붙인다 — 없으면 앱 안의 상대 경로로 열려서 눌러도 안 간다', () => {
    expect(normalizeLinkInput('drop.app/a')).toBe('https://drop.app/a')
    expect(normalizeLinkInput('www.a.com')).toBe('https://www.a.com')
  })

  it('이미 스킴이 있으면 그대로 둔다', () => {
    expect(normalizeLinkInput('https://a.com')).toBe('https://a.com')
    expect(normalizeLinkInput('mailto:a@b.com')).toBe('mailto:a@b.com')
  })

  it('앞뒤 공백을 턴다 — 붙여넣기에 줄바꿈이 섞여 온다', () => {
    expect(normalizeLinkInput('  https://a.com\n')).toBe('https://a.com')
  })

  it('주소로 볼 수 없으면 걸지 않는다 — "회의록"이 링크가 되면 안 된다', () => {
    expect(normalizeLinkInput('회의록')).toBeNull()
    expect(normalizeLinkInput('')).toBeNull()
    expect(normalizeLinkInput('   ')).toBeNull()
  })

  it('말이 섞여 붙여넣어졌으면 주소만 뽑는다', () => {
    expect(normalizeLinkInput('여기 봐 https://a.com/x 고마워')).toBe('https://a.com/x')
  })
})
