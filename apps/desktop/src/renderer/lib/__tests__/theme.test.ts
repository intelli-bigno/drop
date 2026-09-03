/**
 * @vitest-environment jsdom
 */
import { describe, it, expect, beforeEach } from 'vitest'
import {
  THEME_PREFERENCES,
  THEME_STORAGE_KEY,
  applyThemePreference,
  readThemePreference,
  themeAttribute,
} from '../theme'

/** getItem/setItem만 있는 최소 저장소 — 실제 localStorage 없이도 규칙을 잰다. */
function fakeStorage(initial: Record<string, string> = {}) {
  const data = new Map(Object.entries(initial))
  return {
    getItem: (key: string) => data.get(key) ?? null,
    setItem: (key: string, value: string) => void data.set(key, value),
    get size() {
      return data.size
    },
  }
}

describe('themeAttribute', () => {
  it('라이트·다크는 data-theme 값을 그대로 낸다', () => {
    expect(themeAttribute('light')).toBe('light')
    expect(themeAttribute('dark')).toBe('dark')
  })

  it('시스템은 값이 없다 — 속성을 지워야 OS 설정이 다시 결정권을 갖는다', () => {
    expect(themeAttribute('system')).toBeNull()
  })
})

describe('readThemePreference', () => {
  it('저장된 값이 없으면 시스템이다', () => {
    expect(readThemePreference(fakeStorage())).toBe('system')
  })

  it('저장된 값을 읽는다', () => {
    expect(readThemePreference(fakeStorage({ [THEME_STORAGE_KEY]: 'dark' }))).toBe('dark')
  })

  it('모르는 값은 시스템으로 떨어진다 — 옛 값이 남아 있어도 앱이 서야 한다', () => {
    expect(readThemePreference(fakeStorage({ [THEME_STORAGE_KEY]: 'sepia' }))).toBe('system')
  })

  it('저장소를 못 읽어도 던지지 않는다', () => {
    const broken = {
      getItem: () => {
        throw new Error('denied')
      },
    }
    expect(readThemePreference(broken)).toBe('system')
  })
})

describe('applyThemePreference', () => {
  let root: HTMLElement

  beforeEach(() => {
    root = document.createElement('html')
  })

  it('고른 테마를 문서에 세우고 저장한다', () => {
    const storage = fakeStorage()
    applyThemePreference(root, 'dark', storage)
    expect(root.getAttribute('data-theme')).toBe('dark')
    expect(storage.getItem(THEME_STORAGE_KEY)).toBe('dark')
  })

  it('시스템으로 되돌리면 속성이 사라진다 — 값이 남아 있으면 OS를 따라가지 않는다', () => {
    const storage = fakeStorage()
    applyThemePreference(root, 'light', storage)
    applyThemePreference(root, 'system', storage)
    expect(root.hasAttribute('data-theme')).toBe(false)
    expect(storage.getItem(THEME_STORAGE_KEY)).toBe('system')
  })

  it('저장소가 막혀 있어도 화면은 바뀐다 — 저장 실패가 전환을 막으면 안 된다', () => {
    const broken = {
      getItem: () => null,
      setItem: () => {
        throw new Error('quota')
      },
    }
    expect(() => applyThemePreference(root, 'dark', broken)).not.toThrow()
    expect(root.getAttribute('data-theme')).toBe('dark')
  })
})

describe('THEME_PREFERENCES', () => {
  it('세 갈래를 시스템 먼저 늘어놓는다 — 기본값이 맨 앞이어야 세그먼트가 읽힌다', () => {
    expect(THEME_PREFERENCES.map((p) => p.value)).toEqual(['system', 'light', 'dark'])
  })

  it('모두 한글 이름을 갖는다', () => {
    for (const preference of THEME_PREFERENCES) {
      expect(preference.label).toMatch(/^[가-힣]+$/)
    }
  })
})
