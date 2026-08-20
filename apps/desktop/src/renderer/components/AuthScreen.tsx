import { useAuthStore } from '../stores/auth'

export function AuthScreen() {
  const { signInWithGoogle, isAuthLoading } = useAuthStore()

  return (
    <div className="auth-screen">
      <div className="auth-container">
        {/* 앱 아이콘과 같은 마크 — 소스: apps/desktop/build/logo/a-solid-drop.svg */}
        <svg className="auth-logo" viewBox="0 0 1024 1024" width="72" height="72" aria-hidden="true">
          <defs>
            <linearGradient id="auth-logo-bg" x1="0" y1="0" x2="0" y2="1">
              <stop offset="0" stopColor="var(--accent)" />
              <stop offset="1" stopColor="var(--accent-hover)" />
            </linearGradient>
          </defs>
          <rect width="1024" height="1024" rx="229" fill="url(#auth-logo-bg)" />
          <path
            d="M512 236C512 236 704 476 704 598A192 192 0 0 1 320 598C320 476 512 236 512 236Z"
            fill="var(--bg-card)"
          />
        </svg>
        <h1 className="auth-title">DROP</h1>
        <p className="auth-subtitle">생각을 떨어뜨리는 가장 빠른 곳</p>

        <button
          className="google-signin-button"
          onClick={signInWithGoogle}
          disabled={isAuthLoading}
        >
          <svg className="google-icon" viewBox="0 0 24 24" width="20" height="20">
            <path
              fill="#4285F4"
              d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z"
            />
            <path
              fill="#34A853"
              d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z"
            />
            <path
              fill="#FBBC05"
              d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z"
            />
            <path
              fill="#EA4335"
              d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z"
            />
          </svg>
          {isAuthLoading ? '로그인 중...' : 'Google로 로그인'}
        </button>
      </div>

      <style>{`
        .auth-screen {
          display: flex;
          align-items: center;
          justify-content: center;
          min-height: 100vh;
          background: var(--bg-primary);
          -webkit-app-region: drag;
        }

        .auth-container {
          display: flex;
          flex-direction: column;
          align-items: center;
          gap: 16px;
          padding: 48px;
          -webkit-app-region: no-drag;
        }

        .auth-logo {
          display: block;
          border-radius: 18px;
        }

        .auth-title {
          font-size: 48px;
          font-weight: 700;
          color: var(--text-primary);
          margin: 0;
          letter-spacing: -1px;
        }

        .auth-subtitle {
          font-size: 16px;
          color: var(--text-secondary);
          margin: 0 0 32px 0;
        }

        .google-signin-button {
          display: flex;
          align-items: center;
          gap: 12px;
          padding: 12px 24px;
          font-size: 16px;
          font-weight: 500;
          color: var(--text-on-accent);
          background: #ffffff;
          border: none;
          border-radius: 8px;
          cursor: pointer;
          transition: all 0.2s;
        }

        .google-signin-button:hover:not(:disabled) {
          background: #f0f0f0;
          transform: translateY(-1px);
        }

        .google-signin-button:disabled {
          opacity: 0.6;
          cursor: not-allowed;
        }

        .google-icon {
          flex-shrink: 0;
        }
      `}</style>
    </div>
  )
}
