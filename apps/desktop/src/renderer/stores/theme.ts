import { create } from 'zustand'
import {
  applyThemePreference,
  readThemePreference,
  resolvedTheme,
  systemPrefersDark,
  toggleThemePreference,
  type ThemePreference,
} from '../lib/theme'

interface ThemeState {
  preference: ThemePreference
  /** 지금 **눈에 보이는** 모드. 시스템을 고른 상태에서 OS가 바뀌면 이것만 바뀐다. */
  resolved: 'light' | 'dark'
  setPreference: (preference: ThemePreference) => void
  /** 글쇠 한 벌·버튼 한 번으로 보이는 것의 반대로 (BRU-213). */
  toggle: () => void
}

/**
 * 테마 선택 (BRU-213). 규칙은 `lib/theme.ts`에 있고 여기는 그것을 화면에 잇는다.
 *
 * 초기값을 **모듈이 올라오는 순간** 적용한다 — 이펙트로 미루면 첫 그림이 OS
 * 설정으로 한 번 칠해졌다가 바뀌어, 라이트를 고른 사람에게 다크가 한 번 번쩍인다.
 */
const initial = readThemePreference(window.localStorage)
applyThemePreference(document.documentElement, initial, window.localStorage)

export const useThemeStore = create<ThemeState>()((set, get) => ({
  preference: initial,
  resolved: resolvedTheme(initial, systemPrefersDark()),
  setPreference: (preference) => {
    applyThemePreference(document.documentElement, preference, window.localStorage)
    set({ preference, resolved: resolvedTheme(preference, systemPrefersDark()) })
  },
  toggle: () => {
    get().setPreference(toggleThemePreference(get().preference, systemPrefersDark()))
  },
}))

// 시스템을 고른 채로 OS 설정이 바뀌면 화면은 저절로 따라가지만 `resolved`는
// 그대로다 — 그러면 전환 버튼이 이미 보이는 쪽을 가리키게 된다.
if (typeof window !== 'undefined' && typeof window.matchMedia === 'function') {
  window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', () => {
    const { preference } = useThemeStore.getState()
    useThemeStore.setState({ resolved: resolvedTheme(preference, systemPrefersDark()) })
  })
}
