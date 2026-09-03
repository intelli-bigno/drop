import { describe, it, expect } from 'vitest'
import { copyResultMessage } from '../copy-feedback'

describe('copyResultMessage', () => {
  it('내용을 복사하면 무엇이 복사됐는지 말한다', () => {
    expect(copyResultMessage('copyFocused', true)).toEqual({
      message: '노트 내용을 복사했습니다',
      icon: 'check',
      duration: 1800,
    })
  })

  it('참조 링크는 내용과 다른 것이라 다르게 말한다 — 둘을 같은 말로 알리면 어느 쪽이 갔는지 모른다', () => {
    expect(copyResultMessage('copyFocusedReference', true)).toEqual({
      message: '참조 링크를 복사했습니다',
      icon: 'check',
      duration: 1800,
    })
  })

  it('성공은 오래 붙잡아 두지 않는다 — 확인은 눈길 한 번이면 끝나고, 그 뒤로는 화면을 가릴 뿐이다', () => {
    const ok = copyResultMessage('copyFocused', true)
    const failed = copyResultMessage('copyFocused', false)
    expect(ok.duration).toBeLessThan(failed.duration ?? 4000)
  })

  it('실패에는 체크 표시를 붙이지 않는다 — 됐다는 신호가 안 된 자리에 있으면 안 된다', () => {
    expect(copyResultMessage('copyFocused', false).icon).toBeUndefined()
  })

  it('실패는 조용히 넘기지 않는다 — 클립보드는 눌러도 아무 일이 안 일어나는 것처럼 보인다', () => {
    expect(copyResultMessage('copyFocused', false)).toEqual({
      message: '복사하지 못했습니다',
      variant: 'error',
    })
    expect(copyResultMessage('copyFocusedReference', false).variant).toBe('error')
  })
})
