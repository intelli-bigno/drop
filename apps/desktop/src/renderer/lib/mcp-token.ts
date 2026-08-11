// MCP 토큰 발급 판단.
//
// 키는 서버에 sha256 해시로만 저장되므로 평문은 발급 시 1회만 받을 수 있다.
// `get_mcp_api_key()`는 이미 발급된 경우 평문 대신 접두사(`left(key, 9)`)만 돌려준다 —
// 이 접두사도 'drop_'로 시작하기 때문에, 접두사 유무만으로 평문 여부를 판단하면 안 된다.

const TOKEN_PREFIX = 'drop_'
/** 발급된 키는 'drop_' + base64(24바이트). 접두사(9자)와 확실히 구분되는 하한. */
const MIN_PLAINTEXT_LENGTH = 20

export type McpTokenAction = 'generate' | 'confirm-regenerate'

/** 서버가 돌려준 값이 클립보드에 복사해도 되는 평문 키인지 */
export function isPlaintextToken(value: string | null): boolean {
  if (!value) return false
  return value.startsWith(TOKEN_PREFIX) && value.length >= MIN_PLAINTEXT_LENGTH
}

/**
 * 기존 키 접두사를 보고 다음 행동을 결정한다.
 * - 발급 이력 없음 → 바로 생성
 * - 이미 있음 → 재발급은 기존 키를 무효화하므로 확인을 받는다
 */
export function decideMcpTokenAction(existingPrefix: string | null): McpTokenAction {
  return existingPrefix ? 'confirm-regenerate' : 'generate'
}
