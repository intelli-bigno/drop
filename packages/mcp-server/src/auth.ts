import { readFileSync, writeFileSync, existsSync } from 'fs'
import { join, dirname } from 'path'
import { fileURLToPath } from 'url'

const __dirname = dirname(fileURLToPath(import.meta.url))
const ENV_PATH = join(__dirname, '..', '.env')

// eslint-disable-next-line @typescript-eslint/no-unused-vars
interface AuthTokens {
  accessToken: string
  refreshToken: string
  expiresAt: number
}

/**
 * .env 파일에서 refresh token 읽기
 */
export function loadRefreshToken(): string | null {
  if (!existsSync(ENV_PATH)) {
    return null
  }

  const envContent = readFileSync(ENV_PATH, 'utf-8')
  const match = envContent.match(/^SUPABASE_REFRESH_TOKEN=(.+)$/m)
  return match ? match[1].trim() : null
}

/**
 * .env 파일에 refresh token 저장
 */
export function saveRefreshToken(refreshToken: string): void {
  let envContent = ''

  if (existsSync(ENV_PATH)) {
    envContent = readFileSync(ENV_PATH, 'utf-8')
  }

  // 기존 SUPABASE_REFRESH_TOKEN 라인 제거 (주석 포함)
  // 주석 처리된 라인도 제거하고 새로 추가
  envContent = envContent.replace(/^#?\s*SUPABASE_REFRESH_TOKEN=.*$/gm, '')

  // 빈 줄 정리 후 토큰 추가
  envContent = envContent.trimEnd() + `\nSUPABASE_REFRESH_TOKEN=${refreshToken}\n`

  writeFileSync(ENV_PATH, envContent)
}

/**
 * 인증 여부 확인
 */
export function isAuthenticated(): boolean {
  return loadRefreshToken() !== null
}
