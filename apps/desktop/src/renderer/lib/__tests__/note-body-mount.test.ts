import { describe, it, expect } from 'vitest'
import { shouldMountNoteBody } from '../note-body-mount'

describe('shouldMountNoteBody', () => {
  it('접힌 카드는 본문을 마운트하지 않는다', () => {
    expect(
      shouldMountNoteBody({ view: 'one-line', hasEnteredViewport: true, isFocused: false })
    ).toBe(false)
  })

  it('포커스된 카드는 뷰포트 관측을 기다리지 않는다', () => {
    // j/k로 막 넘어온 카드는 스크롤이 끝나기 전에도 본문이 보여야 한다
    expect(
      shouldMountNoteBody({ view: 'viewer', hasEnteredViewport: false, isFocused: true })
    ).toBe(true)
  })

  it('편집 중인 카드는 언제나 마운트한다', () => {
    expect(
      shouldMountNoteBody({ view: 'editor', hasEnteredViewport: false, isFocused: true })
    ).toBe(true)
  })

  it('전체 펼치기로 열렸지만 화면 밖인 카드는 본문을 마운트하지 않는다', () => {
    // BRU-79의 블로커 — N개를 한꺼번에 마운트하면 요청이 폭주한다
    expect(
      shouldMountNoteBody({ view: 'viewer', hasEnteredViewport: false, isFocused: false })
    ).toBe(false)
  })

  it('한 번 뷰포트에 들어온 카드는 마운트한다', () => {
    expect(
      shouldMountNoteBody({ view: 'viewer', hasEnteredViewport: true, isFocused: false })
    ).toBe(true)
  })
})
