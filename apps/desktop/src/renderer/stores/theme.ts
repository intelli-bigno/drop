import { create } from 'zustand'
import {
  applyThemePreference,
  readThemePreference,
  type ThemePreference,
} from '../lib/theme'

interface ThemeState {
  preference: ThemePreference
  setPreference: (preference: ThemePreference) => void
}

/**
 * 테마 선택 (BRU-213). 규칙은 `lib/theme.ts`에 있고 여기는 그것을 화면에 잇는다.
 *
 * 초기값을 **모듈이 올라오는 순간** 적용한다 — 이펙트로 미루면 첫 그림이 OS
 * 설정으로 한 번 칠해졌다가 바뀌어, 라이트를 고른 사람에게 다크가 한 번 번쩍인다.
 */
const initial = readThemePreference(window.localStorage)
applyThemePreference(document.documentElement, initial, window.localStorage)

export const useThemeStore = create<ThemeState>()((set) => ({
  preference: initial,
  setPreference: (preference) => {
    applyThemePreference(document.documentElement, preference, window.localStorage)
    set({ preference })
  },
}))
