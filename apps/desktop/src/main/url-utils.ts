const SAFE_EXTERNAL_PROTOCOLS = new Set(['http:', 'https:', 'mailto:'])

/**
 * 외부(기본 브라우저/메일 클라이언트)로 여는 것이 안전한 URL인지 검증한다.
 * http:, https:, mailto: 프로토콜만 허용하고 나머지(file:, smb:, javascript: 등)는 거부한다.
 */
export function isSafeExternalUrl(url: string): boolean {
  if (typeof url !== 'string' || url.length === 0) return false

  let parsed: URL
  try {
    parsed = new URL(url)
  } catch {
    return false
  }

  return SAFE_EXTERNAL_PROTOCOLS.has(parsed.protocol)
}
