import { Suspense, lazy, useCallback, useEffect, useState } from 'react'
import { useNotesStore } from './stores/notes'
import { useAuthStore } from './stores/auth'
import { useProfileStore } from './stores/profile'
import { NoteFeed } from './components/NoteFeed'
import { AuthScreen } from './components/AuthScreen'
import { QuickCapture } from './components/QuickCapture'
import { UserMenu } from './components/UserMenu'
import { Toaster } from './components/Toaster'
import { HintLayer } from './components/HintLayer'
import { ShortcutCheatSheet } from './components/ShortcutCheatSheet'
import { isCheatSheetShortcut } from './shortcuts/noteGlobal'
import { isTextInputTarget } from './lib/dom-utils'
import { resolveAppRoute } from './lib/app-route'

// 디자인 시스템 쇼케이스 (BRU-172) — 개발 전용.
// 프로덕션에서는 이 삼항이 죽은 가지가 되어 모듈째로 번들에서 사라진다.
const Styleguide = import.meta.env.DEV
  ? lazy(() => import('./styleguide').then((m) => ({ default: m.Styleguide })))
  : null

const isLocal = import.meta.env.VITE_SUPABASE_URL?.includes('127.0.0.1')
const envLabel = isLocal ? 'LOCAL' : 'REMOTE'

function App() {
  const [route, setRoute] = useState(() => resolveAppRoute(window.location.hash))

  // Handle hash-based routing
  useEffect(() => {
    const handleHashChange = () => {
      setRoute(resolveAppRoute(window.location.hash))
    }
    window.addEventListener('hashchange', handleHashChange)
    return () => window.removeEventListener('hashchange', handleHashChange)
  }, [])

  // Quick Capture route - minimal UI, separate window
  // 여기서 걸러야 아래 MainApp이 마운트되지 않는다 — 훅은 조건부로 건너뛸 수
  // 없으므로, 이 창에 데이터 로딩 이펙트가 돌지 않으려면 컴포넌트 자체를
  // 아예 렌더하지 말아야 한다 (BRU-180).
  if (route === 'quick-capture') {
    return <QuickCapture />
  }

  // 디자인 시스템 쇼케이스 (BRU-172). 인증 앞단에서 갈라진다 — 로그인도 Supabase도 필요 없다.
  // 마찬가지로 MainApp을 마운트하지 않아야 픽스처 위에 실제 노트가 덮이지 않는다.
  if (Styleguide && route === 'styleguide') {
    return (
      <Suspense fallback={null}>
        <Styleguide />
      </Suspense>
    )
  }

  return <MainApp />
}

function MainApp() {
  const { loadNotes, loadTags, loadProjects, subscribeToChanges, createNote } = useNotesStore()
  const { user, isAuthLoading, initializeAuth } = useAuthStore()
  const loadProfile = useProfileStore((s) => s.loadProfile)
  const [isCheatSheetOpen, setIsCheatSheetOpen] = useState(false)

  // ⌘/ 또는 ? 로 단축키 치트시트. 맨 `/`는 편집 진입 키라 여기서 잡지 않는다 (BRU-53).
  // '?'는 수식키가 없으므로 입력 중에는 무시한다.
  const handleCheatSheetKey = useCallback((e: KeyboardEvent) => {
    if (!isCheatSheetShortcut(e)) return
    if (!e.metaKey && !e.ctrlKey && isTextInputTarget(e.target)) return
    e.preventDefault()
    setIsCheatSheetOpen((open) => !open)
  }, [])

  useEffect(() => {
    window.addEventListener('keydown', handleCheatSheetKey)
    return () => window.removeEventListener('keydown', handleCheatSheetKey)
  }, [handleCheatSheetKey])

  // Listen for quick capture note creation from main process
  useEffect(() => {
    if (!user) return
    const unsubscribe = window.api.quickCapture.onNoteCreated((content) => {
      createNote(content)
    })
    return () => {
      unsubscribe()
    }
  }, [user, createNote])

  // Listen for refresh event from QuickCapture (파일/이미지/특수URL 직접 저장 후)
  useEffect(() => {
    if (!user) return
    const unsubscribe = window.api.quickCapture.onRefresh(() => {
      // QuickCapture에서 직접 저장했으므로 노트 목록 새로고침
      loadNotes()
    })
    return () => {
      unsubscribe()
    }
  }, [user, loadNotes])

  // Initialize auth on mount
  useEffect(() => {
    initializeAuth()
  }, [initializeAuth])

  // Load data when authenticated
  useEffect(() => {
    if (!user) return

    loadNotes()
    loadTags()
    loadProjects()
    loadProfile()

    // Realtime 구독 시작
    const unsubscribe = subscribeToChanges()

    return () => {
      unsubscribe()
    }
  }, [user, loadNotes, loadTags, loadProjects, loadProfile, subscribeToChanges])

  // Show loading state while checking auth
  if (isAuthLoading) {
    // 글자로 기다리게 하지 않는다 (BRU-213) — 'Loading...'은 이 앱에서 유일하게
    // 영어로 말을 거는 자리였고, 그마저 아무 정보도 주지 않았다.
    return <div className="app-booting" aria-label="여는 중" />
  }

  // Show auth screen if not logged in
  if (!user) {
    return <AuthScreen />
  }

  return (
    <div className="app">
      <div className="app-header">
        <div className="app-header-right">
          {import.meta.env.DEV && (
            /* 어느 DB에 붙어 있는지 (개발 창 전용). 색 알약이 아니라 점 하나 +
               작은 글자다 — 상용 화면에는 없는 것이 헤더에서 가장 눈에 띄면 안 된다. */
            <span className={`env-badge ${isLocal ? 'is-local' : ''}`}>{envLabel}</span>
          )}
          <UserMenu onOpenCheatSheet={() => setIsCheatSheetOpen(true)} />
        </div>
      </div>

      <div className="app-content">
        <NoteFeed />
      </div>

      {isCheatSheetOpen && <ShortcutCheatSheet onClose={() => setIsCheatSheetOpen(false)} />}
      <Toaster />
      {/* 아이콘 버튼에 설명과 글쇠를 함께 띄운다 (BRU-213). 앱에 하나만 선다. */}
      <HintLayer />
    </div>
  )
}

export default App
