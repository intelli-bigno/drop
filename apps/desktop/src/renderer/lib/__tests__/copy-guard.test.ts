import { describe, expect, it } from 'vitest'
import { shouldYieldToNativeCopy } from '../copy-guard'

/**
 * ⌘C를 노트 복사에 묶으면서도 OS 복사를 빼앗지 않기 위한 판정 (BRU-104).
 * 사용자가 텍스트를 긁어 놓고 ⌘C를 눌렀는데 노트 전체가 복사되면 그건 회귀다.
 */
describe('shouldYieldToNativeCopy', () => {
  it('선택된 텍스트가 있으면 OS 복사에 넘긴다', () => {
    expect(shouldYieldToNativeCopy({ selectionText: '긁어 놓은 조각' })).toBe(true)
  })

  it('선택이 없으면 노트 복사가 가져간다', () => {
    expect(shouldYieldToNativeCopy({ selectionText: '' })).toBe(false)
    expect(shouldYieldToNativeCopy({ selectionText: null })).toBe(false)
  })

  it('공백만 있는 선택은 선택이 아니다 — 클릭 한 번에 생기는 빈 range를 걸러낸다', () => {
    expect(shouldYieldToNativeCopy({ selectionText: '   \n  ' })).toBe(false)
  })
})
