/**
 * 사용자 설정 영속화 (BRU-84).
 *
 * 파싱·직렬화는 순수 함수로 두고, 디스크 접근은 얇은 래퍼 둘로 격리한다.
 * 설정 파일이 깨져도 앱은 기본값으로 뜨는 것이 원칙이다.
 */
import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'fs'
import { dirname, join } from 'path'
import { normalizeAccelerator } from '../shared/shortcuts'

export interface AppSettings {
  /** 사용자가 고른 전역 퀵캡처 조합. null이면 빌드 기본값을 쓴다. */
  quickCaptureShortcut: string | null
}

export const DEFAULT_SETTINGS: AppSettings = {
  quickCaptureShortcut: null,
}

export function parseSettings(raw: string | null | undefined): AppSettings {
  if (!raw) return { ...DEFAULT_SETTINGS }

  let payload: unknown
  try {
    payload = JSON.parse(raw)
  } catch {
    return { ...DEFAULT_SETTINGS }
  }

  if (typeof payload !== 'object' || payload === null || Array.isArray(payload)) {
    return { ...DEFAULT_SETTINGS }
  }

  const stored = (payload as Record<string, unknown>).quickCaptureShortcut
  const quickCaptureShortcut =
    typeof stored === 'string' ? normalizeAccelerator(stored) : null

  return { quickCaptureShortcut }
}

export function serializeSettings(settings: AppSettings): string {
  return `${JSON.stringify({ quickCaptureShortcut: settings.quickCaptureShortcut }, null, 2)}\n`
}

/** 조합을 바꾼 새 설정을 돌려준다. 잘못된 조합은 저장하지 않고 던진다. */
export function withQuickCaptureShortcut(
  settings: AppSettings,
  accelerator: string | null
): AppSettings {
  if (accelerator === null) return { ...settings, quickCaptureShortcut: null }

  const normalized = normalizeAccelerator(accelerator)
  if (!normalized) {
    throw new Error(`유효하지 않은 단축키 조합입니다: ${accelerator}`)
  }

  return { ...settings, quickCaptureShortcut: normalized }
}

export function settingsFilePath(userDataDir: string): string {
  return join(userDataDir, 'settings.json')
}

export function loadSettings(userDataDir: string): AppSettings {
  const path = settingsFilePath(userDataDir)
  if (!existsSync(path)) return { ...DEFAULT_SETTINGS }

  try {
    return parseSettings(readFileSync(path, 'utf8'))
  } catch (error) {
    console.warn('[settings] 읽기 실패 — 기본값으로 진행합니다:', error)
    return { ...DEFAULT_SETTINGS }
  }
}

export function saveSettings(userDataDir: string, settings: AppSettings): void {
  const path = settingsFilePath(userDataDir)
  mkdirSync(dirname(path), { recursive: true })
  writeFileSync(path, serializeSettings(settings), 'utf8')
}
