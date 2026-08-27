import type { Api, QuickCaptureShortcutState } from '../../preload'
import { DEFAULT_QUICK_CAPTURE_ACCELERATOR } from '../../shared/shortcuts'
import { supabase } from './supabase'

/**
 * 개발 전용 — 로그인 없이 화면을 띄우기 위한 경로 (BRU-71).
 *
 * iOS의 `-dropPreview`(`PreviewLaunch.swift`)와 같은 자리다. 다른 점은 **인메모리
 * 표본이 아니라 로컬 Supabase의 실제 세션**을 쓴다는 것: 화면만 그려 보는 것이
 * 목적이 아니라 "DB 컬럼이 화면까지 흘러오는지"를 보려는 것이라, 쿼리 경로를
 * 건너뛰면 아무것도 증명하지 못한다.
 *
 * 시드 사용자는 `supabase/seed.sql`이 만든다. 비밀번호가 코드에 박혀 있어도
 * 되는 이유는 그 사용자가 로컬 컨테이너 안에만 있기 때문이다 — 리모트에는 없다.
 *
 * ## 프로덕션 빌드에는 들어가지 않는다
 *
 * 호출부가 `import.meta.env.DEV` 안에 있어 프로덕션 번들에서 통째로 사라진다.
 * 확인 방법은 `apps/desktop/README` 대신 BRU-71 코멘트에 실측으로 남긴다:
 * 빌드 산출물에서 `dropPreviewSignIn` 문자열이 0건이어야 한다.
 */
export const PREVIEW_EMAIL = 'preview@drop.local'
export const PREVIEW_PASSWORD = 'drop-preview-password'

/** 프리뷰 모드로 띄우라는 지시가 있는가 (개발 빌드에서만 의미가 있다) */
export function isPreviewRequested(): boolean {
  return import.meta.env.DEV && import.meta.env.VITE_DROP_PREVIEW === '1'
}

/**
 * Electron 밖(일반 브라우저)에서도 화면이 뜨게 `window.api`를 흉내 낸다.
 *
 * 렌더러는 Electron preload가 심어 주는 `window.api`를 있다고 보고 쓴다. 브라우저로
 * 같은 dev 서버를 열면 그 자리가 비어 있어 화면이 통째로 죽는다 — 실제로
 * 「전역 단축키」를 여는 순간 `Cannot read properties of undefined (reading
 * 'getQuickCaptureShortcut')`으로 root가 빈 채 하얘졌다 (BRU-111 실측).
 *
 * 그래서 반환 타입을 preload의 `Api`에 **묶어 둔다**. preload에 새 IPC가 생기면
 * 여기가 컴파일에서 터진다 — shim이 뒤처져 브라우저에서만 죽는 일을 두 번 겪지
 * 않기 위한 장치다. (`import type`이라 런타임 의존은 없다. preload 모듈은 번들에
 * 들어오지 않는다.)
 *
 * 흉내 내는 것은 **모양뿐**이다. 아래 주석은 두 가지를 구분한다:
 *   - `[흉내]`  브라우저에서도 뜻이 통하는 것 (버전 문자열, 외부 링크 열기 등)
 *   - `[Electron 전용]` 브라우저에는 대응물이 아예 없는 것. **성공한 척하지 않는다** —
 *     거짓 성공을 돌려주면 화면이 "됐다"고 표시하고, 브라우저에서 통과한 것이
 *     Electron에서도 된다는 착각을 만든다.
 */
export function installPreviewApiShim(): void {
  if (!import.meta.env.DEV) return
  const target = window as unknown as { api?: unknown }
  if (target.api) return

  target.api = createPreviewApi()
}

/** 브라우저에서 쓸 `window.api` 대역. preload의 표면을 그대로 덮는다. */
function createPreviewApi(): Api {
  const noop = (): void => {}
  const unsubscribe = (): (() => void) => noop

  /**
   * 브라우저에는 OS 전역 단축키가 없다 — `registered: false`가 정직한 답이다.
   * `accelerator`를 채워 주면 설정 화면이 "이 조합으로 어디서든 열린다"고 거짓말한다.
   */
  const shortcutState = (): QuickCaptureShortcutState => ({
    accelerator: null,
    custom: null,
    fallback: DEFAULT_QUICK_CAPTURE_ACCELERATOR,
    registered: false,
  })

  return {
    // [흉내] describeShortcutState·formatAccelerator가 ⌘/⌥ 표기를 고르는 데 쓴다.
    platform: browserPlatform(),

    // [흉내] 실제로 열지는 않는다. 브라우저에서 새 탭을 열어 버리면 Electron의
    // "시스템 브라우저로 넘긴다"와 동작이 달라져 검증이 오히려 흐려진다.
    openExternal: async (url: string) => {
      console.info('[preview] openExternal는 흉내만 낸다:', url)
    },

    updater: {
      // [흉내] 화면에 찍히는 버전 문자열. 프리뷰임을 드러내는 값을 쓴다.
      getVersion: async () => '0.0.0-preview',
      // [Electron 전용] 자동 업데이트. UserMenu는 이벤트가 하나도 안 오면
      // "개발 빌드에서는 업데이트를 확인하지 않습니다"를 그대로 보여 준다.
      check: async () => {},
      download: async () => {},
      install: async () => {},
      onChecking: unsubscribe,
      onAvailable: unsubscribe,
      onNotAvailable: unsubscribe,
      onDownloaded: unsubscribe,
      onProgress: unsubscribe,
      onError: unsubscribe,
    },

    quickCapture: {
      // [Electron 전용] 별도 창을 띄우는 일. 브라우저에서 이 화면을 보려면
      // 해시 라우트로 직접 들어간다: http://localhost:5173/#quick-capture
      open: async () => {},
      close: async () => {},
      // [Electron 전용] 메인 윈도우로 넘기는 IPC. 넘길 창이 없으므로
      // `handledByMainWindow: false`가 사실이다.
      submit: async () => ({ success: false, handledByMainWindow: false }),
      notifyRefresh: async () => {},
      // [Electron 전용] 별도 창 setBounds. 브라우저에는 창이 없다.
      setHeight: async () => {},
      onNoteCreated: unsubscribe,
      onRefresh: unsubscribe,
    },

    settings: {
      // [Electron 전용] globalShortcut 등록. 못 한다고 말한다 — 위 shortcutState 주석 참고.
      getQuickCaptureShortcut: async () => shortcutState(),
      setQuickCaptureShortcut: async () => ({
        ok: false,
        error: '브라우저에서는 전역 단축키를 등록할 수 없습니다 — Electron 창에서 확인하세요.',
        state: shortcutState(),
      }),
    },

    // [Electron 전용] 커스텀 프로토콜(drop://) 콜백. 브라우저에는 오지 않는다.
    auth: { onCallback: unsubscribe },

    // [Electron 전용] 숨은 BrowserWindow로 긁어 오는 경로. 브라우저에서는 CORS로 막힌다.
    instagram: {
      ensureLogin: async () => false,
      fetchPost: async () => null,
    },
    youtube: { fetchOEmbed: async () => null },
  }
}

/** preload의 `process.platform` 자리. 단축키 표기(⌘·⌥)를 고르는 데만 쓰인다. */
function browserPlatform(): NodeJS.Platform {
  const agent = navigator.userAgent
  if (agent.includes('Mac')) return 'darwin'
  if (agent.includes('Win')) return 'win32'
  return 'linux'
}

/**
 * 시드 사용자로 로그인한다. 성공하면 supabase-js가 세션을 저장하고,
 * `onAuthStateChange`가 앱 상태를 채운다 — 일반 로그인과 같은 경로다.
 */
export async function dropPreviewSignIn(): Promise<void> {
  const { error } = await supabase.auth.signInWithPassword({
    email: PREVIEW_EMAIL,
    password: PREVIEW_PASSWORD,
  })

  if (error) {
    // 조용히 실패하면 "로그인 화면이 뜬 이유"를 찾느라 시간을 버린다.
    console.error(
      `[preview] 시드 사용자로 로그인하지 못했습니다: ${error.message}\n` +
        '로컬 Supabase가 떠 있고 `supabase db reset`으로 시드가 적용됐는지 확인하세요.'
    )
  }
}
