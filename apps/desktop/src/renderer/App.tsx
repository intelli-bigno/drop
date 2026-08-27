import { useCallback, useEffect, useState } from 'react'
import { useNotesStore } from './stores/notes'
import { useAuthStore } from './stores/auth'
import { useProfileStore } from './stores/profile'
import { NoteFeed } from './components/NoteFeed'
import { AuthScreen } from './components/AuthScreen'
import { QuickCapture } from './components/QuickCapture'
import { UserMenu } from './components/UserMenu'
import { Toaster } from './components/Toaster'
import { ShortcutCheatSheet } from './components/ShortcutCheatSheet'
import { isCheatSheetShortcut } from './shortcuts/noteGlobal'
import { isTextInputTarget } from './lib/dom-utils'

const isLocal = import.meta.env.VITE_SUPABASE_URL?.includes('127.0.0.1')
const envLabel = isLocal ? 'LOCAL' : 'REMOTE'

function App() {
  const { loadNotes, loadTags, loadProjects, subscribeToChanges, createNote } = useNotesStore()
  const { user, isAuthLoading, initializeAuth } = useAuthStore()
  const loadProfile = useProfileStore((s) => s.loadProfile)
  const [route, setRoute] = useState(() => window.location.hash.replace('#', '') || 'main')
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

  // Handle hash-based routing
  useEffect(() => {
    const handleHashChange = () => {
      setRoute(window.location.hash.replace('#', '') || 'main')
    }
    window.addEventListener('hashchange', handleHashChange)
    return () => window.removeEventListener('hashchange', handleHashChange)
  }, [])

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

  // Quick Capture route - minimal UI, separate window
  if (route === 'quick-capture') {
    return <QuickCapture />
  }

  // Show loading state while checking auth
  if (isAuthLoading) {
    return (
      <div
        style={{
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          minHeight: '100vh',
          background: 'var(--bg-primary)',
          color: 'var(--text-tertiary)',
        }}
      >
        Loading...
      </div>
    )
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
            <div
              style={{
                padding: '4px 8px',
                borderRadius: 4,
                fontSize: 11,
                fontWeight: 600,
                color: 'var(--text-on-accent)',
                backgroundColor: isLocal ? 'var(--success)' : 'var(--warning)',
                opacity: 0.9,
              }}
            >
              {envLabel}
            </div>
          )}
          <UserMenu onOpenCheatSheet={() => setIsCheatSheetOpen(true)} />
        </div>
      </div>

      <div className="app-content">
        <NoteFeed />
      </div>

      {isCheatSheetOpen && <ShortcutCheatSheet onClose={() => setIsCheatSheetOpen(false)} />}
      <Toaster />
    </div>
  )
}

export default App
