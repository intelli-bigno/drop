/**
 * PIN 해시/검증은 서버 RPC(set_note_pin / verify_note_pin, bcrypt)에서 수행.
 * 클라이언트에는 형식 검사만 남긴다.
 */

/**
 * PIN 유효성 검사 (4-6자리 숫자)
 */
export function isValidPin(pin: string): boolean {
  return /^\d{4,6}$/.test(pin)
}
