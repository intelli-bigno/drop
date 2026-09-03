// 디자인 시스템 쇼케이스 (BRU-172).
//
// `#styleguide`로 들어온다. 인증 앞단에서 갈라지므로 로그인도 Supabase도 필요 없다 —
// 퀵캡처 라우트와 같은 자리다(App.tsx).
//
// 개발 전용이다: App.tsx의 호출부가 `import.meta.env.DEV` 안에 있어 프로덕션 번들에는
// 이 모듈이 통째로 들어가지 않는다 (preview-session.ts와 같은 방식).

import { useEffect, useState } from 'react'
import './styleguide.css'
import { seedStyleguideStores } from './seed'
import { Foundations } from './sections/Foundations'
import { Components } from './sections/Components'
import { Patterns } from './sections/Patterns'
import { Layouts } from './sections/Layouts'
import { States } from './sections/States'
import { Audit } from './sections/Audit'
import { Toaster } from '../components/Toaster'
import { HintLayer } from '../components/HintLayer'
import { THEME_PREFERENCES, themeAttribute, type ThemePreference } from '../lib/theme'

const PAGES = [
  { id: 'foundations', label: 'Foundations', hint: '토큰', render: () => <Foundations /> },
  { id: 'components', label: 'Components', hint: '실물 컴포넌트', render: () => <Components /> },
  { id: 'patterns', label: 'Patterns', hint: '노트 행·계층', render: () => <Patterns /> },
  { id: 'layouts', label: 'Layouts', hint: '창과 셸', render: () => <Layouts /> },
  { id: 'states', label: 'States', hint: '빈·로딩·오류', render: () => <States /> },
  { id: 'audit', label: 'Audit', hint: '토큰 미사용', render: () => <Audit /> },
] as const

type PageId = (typeof PAGES)[number]['id']

/** `#styleguide/components` 처럼 두 번째 조각으로 페이지를 고른다. */
function pageFromHash(): PageId {
  const segment = window.location.hash.replace('#', '').split('/')[1]
  const match = PAGES.find((page) => page.id === segment)
  return match?.id ?? 'foundations'
}

export function Styleguide() {
  const [page, setPage] = useState<PageId>(pageFromHash)
  const [theme, setTheme] = useState<ThemePreference>('system')

  // 픽스처는 첫 렌더 전에 부어야 한다 — 컴포넌트가 빈 스토어를 먼저 보면
  // 빈 상태로 한 번 그려졌다가 뒤늦게 채워진다.
  const [seeded] = useState(() => {
    seedStyleguideStores()
    return true
  })

  useEffect(() => {
    const onHashChange = () => setPage(pageFromHash())
    window.addEventListener('hashchange', onHashChange)
    return () => window.removeEventListener('hashchange', onHashChange)
  }, [])

  // 앱과 **같은 규칙**으로 테마를 고정한다 (BRU-213) — 규칙은 lib/theme.ts 하나다.
  // 다만 여기서는 저장하지 않는다: 쇼케이스에서 다크를 보다 나갔다고 앱이 다크로
  // 바뀌면 안 된다. 그래서 applyThemePreference가 아니라 themeAttribute만 쓰고,
  // 나갈 때 속성을 걷는다.
  useEffect(() => {
    const root = document.documentElement
    const attribute = themeAttribute(theme)
    if (attribute === null) root.removeAttribute('data-theme')
    else root.setAttribute('data-theme', attribute)
    return () => root.removeAttribute('data-theme')
  }, [theme])

  if (!seeded) return null

  const active = PAGES.find((p) => p.id === page) ?? PAGES[0]

  return (
    <div className="sg-root">
      <nav className="sg-nav" aria-label="쇼케이스 섹션">
        <div className="sg-brand">
          <div className="sg-brand-title">DROP 디자인 시스템</div>
          <div className="sg-brand-sub">desktop · #styleguide</div>
        </div>

        <div className="sg-nav-list">
          {PAGES.map((item) => (
            <button
              key={item.id}
              className="sg-nav-link"
              aria-current={item.id === page}
              onClick={() => {
                window.location.hash = `styleguide/${item.id}`
                setPage(item.id)
              }}
            >
              {item.label}
              <div className="sg-brand-sub">{item.hint}</div>
            </button>
          ))}
        </div>

        <div className="sg-nav-foot">
          <div className="sg-brand-sub">테마</div>
          <div className="sg-theme-switch" role="group" aria-label="테마 전환">
            {THEME_PREFERENCES.map((preference) => (
              <button
                key={preference.value}
                aria-pressed={theme === preference.value}
                onClick={() => setTheme(preference.value)}
              >
                {preference.label}
              </button>
            ))}
          </div>
          <div className="sg-brand-sub">
            정본 · design-system/drop/tokens.json
          </div>
        </div>
      </nav>

      <main className="sg-main" key={active.id}>
        {active.render()}
      </main>

      {/* 실물 버튼을 진열하는 화면이므로 힌트도 실물이어야 한다 (BRU-213). */}
      <HintLayer />

      <Toaster />
    </div>
  )
}
