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
  /** 단축키 등록 실패 경고를 다시 보지 않겠다고 한 상태. */
  suppressShortcutNotice: boolean
  /**
   * 이 버전이 모르는 키 원문 그대로.
   *
   * 다른(대개 더 새로운) 버전이 쓴 설정을 이 버전이 저장하면서 지워 버리면 안 된다.
   * 아는 키만 정규화하고 나머지는 손대지 않고 그대로 되쓴다 — 원문 보존.
   */
  extra: Record<string, unknown>
}

/** 알려진 키 목록 — 이 밖의 키는 전부 `extra`로 간다. */
const KNOWN_KEYS = ['quickCaptureShortcut', 'suppressShortcutNotice'] as const

function defaultSettings(): AppSettings {
  return { quickCaptureShortcut: null, suppressShortcutNotice: false, extra: {} }
}

export const DEFAULT_SETTINGS: AppSettings = defaultSettings()

export function parseSettings(raw: string | null | undefined): AppSettings {
  if (!raw) return defaultSettings()

  let payload: unknown
  try {
    payload = JSON.parse(raw)
  } catch {
    return defaultSettings()
  }

  if (typeof payload !== 'object' || payload === null || Array.isArray(payload)) {
    return defaultSettings()
  }

  const record = payload as Record<string, unknown>

  const stored = record.quickCaptureShortcut
  const quickCaptureShortcut = typeof stored === 'string' ? normalizeAccelerator(stored) : null

  const extra: Record<string, unknown> = {}
  for (const [key, value] of Object.entries(record)) {
    if (!(KNOWN_KEYS as readonly string[]).includes(key)) extra[key] = value
  }

  return {
    quickCaptureShortcut,
    suppressShortcutNotice: record.suppressShortcutNotice === true,
    extra,
  }
}

export function serializeSettings(settings: AppSettings): string {
  // 모르는 키를 먼저 깔고 아는 키로 덮는다 — 보존하되 우리 값이 이긴다.
  const payload = {
    ...settings.extra,
    quickCaptureShortcut: settings.quickCaptureShortcut,
    suppressShortcutNotice: settings.suppressShortcutNotice,
  }
  return `${JSON.stringify(payload, null, 2)}\n`
}

/** 경고를 다시 보지 않겠다는 선택을 담은 새 설정. */
export function withShortcutNoticeSuppressed(
  settings: AppSettings,
  suppressed: boolean
): AppSettings {
  return { ...settings, suppressShortcutNotice: suppressed }
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
