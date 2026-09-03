import { describe, it, expect } from 'vitest'
import { copyResultMessage } from '../copy-feedback'

describe('copyResultMessage', () => {
  it('내용을 복사하면 무엇이 복사됐는지 말한다', () => {
    expect(copyResultMessage('copyFocused', true)).toEqual({
      message: '노트 내용을 복사했습니다',
    })
  })

  it('참조 링크는 내용과 다른 것이라 다르게 말한다 — 둘을 같은 말로 알리면 어느 쪽이 갔는지 모른다', () => {
    expect(copyResultMessage('copyFocusedReference', true)).toEqual({
      message: '참조 링크를 복사했습니다',
    })
  })

  it('실패는 조용히 넘기지 않는다 — 클립보드는 눌러도 아무 일이 안 일어나는 것처럼 보인다', () => {
    expect(copyResultMessage('copyFocused', false)).toEqual({
      message: '복사하지 못했습니다',
      variant: 'error',
    })
    expect(copyResultMessage('copyFocusedReference', false).variant).toBe('error')
  })
})
