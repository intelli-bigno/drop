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
 * 같은 dev 서버를 열면 `UserMenu`가 `window.api.updater`에서 터지고 앱 전체가 죽는다.
 * 스크린샷을 자동으로 찍으려면(Playwright 등) 이 자리가 비어 있으면 안 된다.
 *
 * 흉내 내는 것은 **모양뿐**이다 — 자동 업데이트·빠른 캡처처럼 Electron이 해야 하는
 * 일은 여기서 하지 않는다. 그 기능을 보려면 Electron으로 띄워야 한다.
 */
export function installPreviewApiShim(): void {
  if (!import.meta.env.DEV) return
  const target = window as unknown as { api?: unknown }
  if (target.api) return

  const noop = (): void => {}
  const unsubscribe = (): (() => void) => noop

  target.api = {
    openExternal: async (url: string) => {
      console.info('[preview] openExternal는 흉내만 낸다:', url)
    },
    updater: {
      getVersion: async () => '0.0.0-preview',
      check: noop,
      onChecking: unsubscribe,
      onAvailable: unsubscribe,
      onNotAvailable: unsubscribe,
      onDownloaded: unsubscribe,
      onError: unsubscribe,
      quitAndInstall: noop,
    },
    quickCapture: {
      onNoteCreated: unsubscribe,
      onRefresh: unsubscribe,
      notifyRefresh: async () => {},
      submit: async () => ({ success: false }),
      close: noop,
    },
    auth: { onCallback: unsubscribe },
    instagram: {
      ensureLogin: async () => false,
      fetchPost: async () => null,
    },
    youtube: { fetchOEmbed: async () => null },
  }
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
