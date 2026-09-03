/**
 * 라이트·다크를 **사람이 고른다** (BRU-213).
 *
 * 토큰(`tokens.css`)에는 개편 전부터 두 모드가 다 있었는데, 앱에 `data-theme`을
 * 세우는 코드가 한 줄도 없어서 OS 설정에만 끌려갔다 — 밤에 시스템을 다크로 두면
 * 낮에 앱을 밝게 쓸 방법이 없었다.
 *
 * 세 갈래를 두는 이유: "시스템"이 없으면 OS를 따라가고 싶은 사람이 계절마다
 * 손으로 바꿔야 한다. 그래서 **기본값은 시스템**이고, 그 상태의 표현은
 * `data-theme` 속성이 **아예 없는 것**이다(값을 넣는 순간 미디어 쿼리가 진다).
 */

export type ThemePreference = 'system' | 'light' | 'dark'

export const THEME_STORAGE_KEY = 'drop.theme'

export const THEME_PREFERENCES: ReadonlyArray<{
  value: ThemePreference
  label: string
}> = [
  { value: 'system', label: '시스템' },
  { value: 'light', label: '라이트' },
  { value: 'dark', label: '다크' },
]

const VALUES = new Set<string>(THEME_PREFERENCES.map((preference) => preference.value))

/** `null`은 "속성을 지운다"는 뜻이다 — 시스템은 값이 아니라 값의 부재다. */
export function themeAttribute(preference: ThemePreference): string | null {
  return preference === 'system' ? null : preference
}

/**
 * 저장된 값을 읽는다. 못 읽거나 모르는 값이면 시스템으로 떨어진다 —
 * 이 함수가 던지면 앱이 아예 안 뜬다.
 */
export function readThemePreference(storage: Pick<Storage, 'getItem'>): ThemePreference {
  try {
    const stored = storage.getItem(THEME_STORAGE_KEY)
    return stored && VALUES.has(stored) ? (stored as ThemePreference) : 'system'
  } catch {
    return 'system'
  }
}

/**
 * 문서에 세우고 저장한다. **저장 실패가 전환을 막지 않는다** — 지금 눈앞의
 * 화면이 바뀌는 것이 다음 실행에 기억되는 것보다 중요하다.
 */
export function applyThemePreference(
  root: Element,
  preference: ThemePreference,
  storage: Pick<Storage, 'getItem' | 'setItem'>
): void {
  const attribute = themeAttribute(preference)
  if (attribute === null) root.removeAttribute('data-theme')
  else root.setAttribute('data-theme', attribute)

  try {
    storage.setItem(THEME_STORAGE_KEY, preference)
  } catch {
    // 저장소가 막혀 있어도 화면은 이미 바뀌었다.
  }
}

/**
 * 지금 **눈에 보이는** 모드. 고른 값이 시스템이면 OS 설정이 답이 된다.
 *
 * 화면에 그려진 것과 저장된 값이 다를 수 있어서 필요하다 — "시스템"은 라이트도
 * 다크도 아니라서, 그 상태에서 무엇이 보이는지는 물어봐야 알 수 있다.
 */
export function resolvedTheme(
  preference: ThemePreference,
  systemPrefersDark: boolean
): 'light' | 'dark' {
  if (preference !== 'system') return preference
  return systemPrefersDark ? 'dark' : 'light'
}

/**
 * 글쇠 한 벌로 모드를 뒤집는다 (BRU-213).
 *
 * 세 갈래를 **순환하지 않는다.** 순환은 원하는 자리에 가려고 두 번 세 번 눌러야
 * 하고, 중간에 "시스템"을 지나면서 화면이 엉뚱하게 한 번 바뀐다. 여기서 하는 일은
 * 하나다 — **지금 보이는 것의 반대로 간다.** 그래서 한 번 더 누르면 되돌아온다.
 *
 * 대신 "시스템"으로는 돌아가지 못한다. 그건 값이 아니라 값의 부재라서 뒤집기의
 * 반대편에 놓을 수 없다 — 세 갈래를 고르는 자리는 사용자 메뉴에 그대로 있다.
 */
export function toggleThemePreference(
  current: ThemePreference,
  systemPrefersDark: boolean
): ThemePreference {
  return resolvedTheme(current, systemPrefersDark) === 'dark' ? 'light' : 'dark'
}

/** 지금 OS가 다크를 원하는지. `matchMedia`가 없는 환경(테스트·구형)에서는 라이트로 본다. */
export function systemPrefersDark(): boolean {
  if (typeof window === 'undefined' || typeof window.matchMedia !== 'function') return false
  return window.matchMedia('(prefers-color-scheme: dark)').matches
}
