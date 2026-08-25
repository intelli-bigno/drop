// @vitest-environment jsdom
import { beforeEach, describe, expect, it, vi } from 'vitest'

// preview-session은 `dropPreviewSignIn` 때문에 supabase 클라이언트를 끌고 온다.
// 그 모듈은 import 시점에 VITE_SUPABASE_URL을 요구하므로 여기서 끊는다 —
// 이 테스트가 보는 것은 shim의 표면이지 로그인이 아니다.
vi.mock('../supabase', () => ({ supabase: { auth: { signInWithPassword: vi.fn() } } }))

import { installPreviewApiShim } from '../preview-session'

type ShimWindow = Omit<Window, 'api'> & { api?: Window['api'] }

function shim() {
  installPreviewApiShim()
  return (window as ShimWindow).api!
}

describe('installPreviewApiShim', () => {
  beforeEach(() => {
    delete (window as ShimWindow).api
  })

  it('ShortcutSettingsDialog가 첫 렌더에서 읽는 자리를 채운다', async () => {
    const api = shim()

    // 이 자리가 비어 있어서 브라우저에서 「전역 단축키」를 열면 앱 전체가 죽었다 (BRU-111 실측).
    expect(typeof api.platform).toBe('string')
    await expect(api.settings.getQuickCaptureShortcut()).resolves.toMatchObject({
      registered: false,
    })
  })

  it('전역 단축키를 등록한 척하지 않는다', async () => {
    const api = shim()

    const state = await api.settings.getQuickCaptureShortcut()
    // 브라우저에는 OS 전역 단축키가 없다. accelerator를 채워 주면 설정 화면이
    // "이 조합으로 어디서든 열린다"고 거짓말한다.
    expect(state.accelerator).toBeNull()

    const result = await api.settings.setQuickCaptureShortcut('Alt+Shift+K')
    expect(result.ok).toBe(false)
    expect(result.error).toBeTruthy()
    expect(result.state.registered).toBe(false)
  })

  it('preload에 있는 나머지 자리도 부르면 터지지 않는다', async () => {
    const api = shim()

    await expect(api.quickCapture.open()).resolves.not.toThrow()
    await expect(api.updater.download()).resolves.not.toThrow()
    await expect(api.updater.install()).resolves.not.toThrow()
    await expect(api.updater.check()).resolves.not.toThrow()
    expect(typeof api.updater.onProgress(() => {})).toBe('function')
  })

  it('Electron 안에서는 preload가 심은 것을 덮지 않는다', () => {
    const real = { platform: 'from-preload' } as unknown as Window['api']
    ;(window as ShimWindow).api = real

    installPreviewApiShim()

    expect((window as ShimWindow).api).toBe(real)
  })
})
