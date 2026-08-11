import { describe, it, expect } from 'vitest'
import { decideMcpTokenAction, isPlaintextToken } from '../mcp-token'

describe('decideMcpTokenAction', () => {
  it('shouldGenerateWhenNoKeyIssuedYet', () => {
    expect(decideMcpTokenAction(null)).toBe('generate')
  })

  it('shouldGenerateWhenPrefixIsEmpty', () => {
    expect(decideMcpTokenAction('')).toBe('generate')
  })

  it('shouldAskBeforeReplacingAnExistingKey', () => {
    expect(decideMcpTokenAction('drop_abc1')).toBe('confirm-regenerate')
  })

  // 회귀 방지: get_mcp_api_key()가 기존 키를 가릴 때도 접두사는 'drop_'로 시작한다.
  // 접두사만 보고 평문 여부를 판단하면 마스킹 문자열을 클립보드에 복사하게 된다.
  it('shouldTreatMaskedPrefixAsExistingKeyNotAsPlaintext', () => {
    expect(isPlaintextToken('drop_abc1')).toBe(false)
    expect(decideMcpTokenAction('drop_abc1')).toBe('confirm-regenerate')
  })
})

describe('isPlaintextToken', () => {
  it('shouldAcceptFullLengthIssuedKey', () => {
    // generate_mcp_api_key()는 'drop_' + base64(24바이트) = 37자를 돌려준다
    expect(isPlaintextToken('drop_' + 'a'.repeat(32))).toBe(true)
  })

  it('shouldRejectShortPrefix', () => {
    expect(isPlaintextToken('drop_abc1')).toBe(false)
  })

  it('shouldRejectNullOrEmpty', () => {
    expect(isPlaintextToken(null)).toBe(false)
    expect(isPlaintextToken('')).toBe(false)
  })

  it('shouldRejectValueWithoutDropPrefix', () => {
    expect(isPlaintextToken('a'.repeat(37))).toBe(false)
  })
})
