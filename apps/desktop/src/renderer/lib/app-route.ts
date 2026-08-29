/**
 * hash 라우팅 판정 (BRU-180).
 *
 * `App`이 어떤 화면(quick-capture / styleguide / main)을 그릴지는 이 순수 함수로
 * 결정한다. 라우트 분기를 데이터 로딩 훅보다 먼저 판정할 수 있어야 `MainApp`을
 * 아예 마운트하지 않는 경로에서 훅이 돌지 않는다.
 */
export type AppRoute = 'main' | 'quick-capture' | 'styleguide'

/** window.location.hash 원문(`#`를 포함할 수도, 안 할 수도 있음)을 받아 라우트를 판정한다. */
export function resolveAppRoute(hash: string): AppRoute {
  const path = hash.replace(/^#/, '')

  if (path === 'quick-capture') return 'quick-capture'
  if (path === 'styleguide' || path.startsWith('styleguide/')) return 'styleguide'

  return 'main'
}
