import { useState, useRef, useEffect } from 'react'
import { createPortal } from 'react-dom'
import { useAuthStore } from '../stores/auth'
import { useThemeStore } from '../stores/theme'
import { THEME_PREFERENCES } from '../lib/theme'
import { supabase } from '../lib/supabase'
import { useToastStore } from '../stores/toast'
import { decideMcpTokenAction, isPlaintextToken } from '../lib/mcp-token'
import { describeUpdateStatus, type UpdateStatus } from '../lib/update-status'
import { Icon } from './Icon'
import { TagManagementDialog } from './TagManagementDialog'
import { ShortcutSettingsDialog } from './ShortcutSettingsDialog'
import { CHEAT_SHEET_MENU_LABEL, formatKeyForDisplay } from '../shortcuts/catalog'
import { KEYS } from '../shortcuts/keys'

// updater 이벤트의 info는 unknown으로 노출된다 — 필요한 필드만 안전하게 꺼낸다
function versionOf(info: unknown): string {
  if (info && typeof info === 'object' && 'version' in info) {
    const version = (info as { version: unknown }).version
    if (typeof version === 'string') return version
  }
  return '?'
}

interface Props {
  onOpenCheatSheet: () => void
}

export function UserMenu({ onOpenCheatSheet }: Props) {
  const { user, signOut } = useAuthStore()
  const themePreference = useThemeStore((s) => s.preference)
  const setThemePreference = useThemeStore((s) => s.setPreference)
  const [isOpen, setIsOpen] = useState(false)
  const [tokenCopied, setTokenCopied] = useState(false)
  const [showTagManagement, setShowTagManagement] = useState(false)
  const [showShortcutSettings, setShowShortcutSettings] = useState(false)
  const menuRef = useRef<HTMLDivElement>(null)
  const triggerRef = useRef<HTMLButtonElement>(null)
  const [dropdownPos, setDropdownPos] = useState({ top: 0, right: 0 })
  const [appVersion, setAppVersion] = useState<string | null>(null)
  const [updateStatus, setUpdateStatus] = useState<UpdateStatus>({ kind: 'idle' })

  // Close menu when clicking outside
  useEffect(() => {
    function handleClickOutside(event: MouseEvent) {
      const target = event.target as Node
      if (
        menuRef.current &&
        !menuRef.current.contains(target) &&
        triggerRef.current &&
        !triggerRef.current.contains(target)
      ) {
        setIsOpen(false)
      }
    }
    document.addEventListener('mousedown', handleClickOutside)
    return () => document.removeEventListener('mousedown', handleClickOutside)
  }, [])

  useEffect(() => {
    void window.api.updater.getVersion().then(setAppVersion)
  }, [])

  // 업데이트 이벤트 구독 — main 프로세스가 이미 내보내고 있으나 화면에 연결된 적이 없었다 (BRU-31)
  useEffect(() => {
    const unsubscribers = [
      window.api.updater.onChecking(() => setUpdateStatus({ kind: 'checking' })),
      window.api.updater.onNotAvailable(() => setUpdateStatus({ kind: 'up-to-date' })),
      window.api.updater.onAvailable((info) =>
        setUpdateStatus({ kind: 'available', version: versionOf(info) })
      ),
      window.api.updater.onDownloaded((info) =>
        setUpdateStatus({ kind: 'downloaded', version: versionOf(info) })
      ),
      window.api.updater.onError((message) => setUpdateStatus({ kind: 'error', message })),
    ]
    return () => unsubscribers.forEach((unsubscribe) => unsubscribe())
  }, [])

  const handleCheckForUpdates = () => {
    if (import.meta.env.DEV) {
      // main 프로세스가 개발 빌드에서는 확인을 건너뛴다 — 무한 '확인 중'을 막는다
      setUpdateStatus({ kind: 'unsupported' })
      return
    }
    setUpdateStatus({ kind: 'checking' })
    void window.api.updater.check()
  }

  // Calculate dropdown position when opening
  const handleToggle = () => {
    if (!isOpen && triggerRef.current) {
      const rect = triggerRef.current.getBoundingClientRect()
      // 우측 정렬 기준. 트리거가 왼쪽에 있으면 right가 커져 메뉴가 화면 밖으로 나가므로 클램프한다.
      const MENU_WIDTH = 260
      const maxRight = Math.max(window.innerWidth - MENU_WIDTH - 8, 8)
      setDropdownPos({
        top: rect.bottom + 8,
        right: Math.min(window.innerWidth - rect.right, maxRight),
      })
    }
    setIsOpen(!isOpen)
  }

  if (!user) return null

  const userEmail = user.email || ''
  const userName = user.user_metadata?.full_name || user.user_metadata?.name || userEmail
  const userAvatar = user.user_metadata?.avatar_url || user.user_metadata?.picture
  const initials = userName.charAt(0).toUpperCase()

  const handleSignOut = async () => {
    setIsOpen(false)
    await signOut()
  }

  const handleCopyMcpToken = async () => {
    const showToast = useToastStore.getState().showToast

    // 키는 서버에 해시로만 저장되므로 평문은 발급 시 1회만 받을 수 있다.
    // get_mcp_api_key()는 이미 발급됐으면 평문이 아니라 접두사만 돌려준다.
    const { data: existingPrefix, error: checkError } = await supabase.rpc('get_mcp_api_key')
    if (checkError) {
      console.error('[mcp] get_mcp_api_key failed', checkError)
      showToast({ message: '토큰 상태를 확인하지 못했습니다', variant: 'error' })
      return
    }

    if (decideMcpTokenAction(existingPrefix as string | null) === 'confirm-regenerate') {
      const ok = window.confirm(
        'MCP 키는 보안상 다시 볼 수 없습니다.\n새 키를 발급하면 기존 키는 즉시 무효화됩니다. 재발급할까요?'
      )
      if (!ok) return
    }

    const { data: issued, error: issueError } = await supabase.rpc('regenerate_mcp_api_key')
    if (issueError) {
      console.error('[mcp] regenerate_mcp_api_key failed', issueError)
      showToast({ message: '토큰을 발급하지 못했습니다', variant: 'error' })
      return
    }

    const token = issued as string | null
    if (!isPlaintextToken(token)) {
      console.error('[mcp] unexpected token payload', token)
      showToast({ message: '토큰을 발급하지 못했습니다', variant: 'error' })
      return
    }

    try {
      await navigator.clipboard.writeText(token as string)
    } catch (err) {
      console.error('[mcp] clipboard write failed', err)
      showToast({ message: '복사에 실패했습니다 — 콘솔에서 토큰을 확인하세요', variant: 'error' })
      return
    }

    setTokenCopied(true)
    showToast({ message: 'MCP 토큰을 복사했습니다' })
    setTimeout(() => setTokenCopied(false), 2000)
  }

  const handleOpenTagManagement = () => {
    setIsOpen(false)
    setShowTagManagement(true)
  }

  const handleOpenShortcutSettings = () => {
    setIsOpen(false)
    setShowShortcutSettings(true)
  }

  const handleOpenCheatSheet = () => {
    setIsOpen(false)
    onOpenCheatSheet()
  }

  const dropdown =
    isOpen &&
    createPortal(
      <div
        className="user-menu-dropdown"
        ref={menuRef}
        style={{ top: dropdownPos.top, right: dropdownPos.right }}
      >
        <div className="user-menu-header">
          {userAvatar ? (
            <img src={userAvatar} alt={userName} className="user-avatar-large" />
          ) : (
            <div className="user-avatar-placeholder-large">{initials}</div>
          )}
          <div className="user-info">
            <span className="user-name">{userName}</span>
            {userName !== userEmail && <span className="user-email">{userEmail}</span>}
          </div>
        </div>

        <div className="user-menu-divider" />

        {/* 테마 (BRU-213). 개편 전에는 OS 설정이 유일한 입구였다 —
            토큰에 라이트가 있는데 앱에서 고를 길이 없었다. */}
        <div className="user-menu-field">
          <span className="user-menu-field-label">테마</span>
          <div className="segmented" role="radiogroup" aria-label="테마">
            {THEME_PREFERENCES.map((preference) => (
              <button
                key={preference.value}
                type="button"
                role="radio"
                aria-checked={themePreference === preference.value}
                className={`segmented-option ${
                  themePreference === preference.value ? 'is-selected' : ''
                }`}
                onClick={() => setThemePreference(preference.value)}
              >
                {preference.label}
              </button>
            ))}
          </div>
        </div>

        <div className="user-menu-divider" />

        <button type="button" className="user-menu-item" onClick={handleOpenCheatSheet}>
          <Icon name="help-circle" size={16} />
          {CHEAT_SHEET_MENU_LABEL}
          <kbd className="user-menu-item-key">{formatKeyForDisplay(KEYS.cheatSheetAlt[0])}</kbd>
        </button>

        <button className="user-menu-item" onClick={handleOpenTagManagement}>
          <Icon name="tag" size={16} />
          태그 관리
        </button>

        <button className="user-menu-item" onClick={handleOpenShortcutSettings}>
          <Icon name="keyboard" size={16} />
          전역 단축키
        </button>

        <button className="user-menu-item" onClick={handleCopyMcpToken}>
          <Icon name="copy" size={16} />
          {tokenCopied ? '복사했습니다' : 'MCP 토큰 복사'}
        </button>

        <div className="user-menu-divider" />

        <div className="user-menu-about">
          <div className="user-menu-version">
            <span>DROP</span>
            <span className="user-menu-version-number">{appVersion ? `v${appVersion}` : '…'}</span>
          </div>
          <button
            type="button"
            className="user-menu-update-btn"
            onClick={handleCheckForUpdates}
            disabled={updateStatus.kind === 'checking'}
          >
            업데이트 확인
          </button>
          {describeUpdateStatus(updateStatus) && (
            <p
              className={`user-menu-update-status ${updateStatus.kind === 'error' ? 'is-error' : ''}`}
            >
              {describeUpdateStatus(updateStatus)}
            </p>
          )}
        </div>

        <div className="user-menu-divider" />

        <button className="user-menu-item" onClick={handleSignOut}>
          <Icon name="log-out" size={16} />
          로그아웃
        </button>
      </div>,
      document.body
    )

  return (
    <>
      <div className="user-menu">
        <button
          ref={triggerRef}
          className="user-menu-trigger"
          onClick={handleToggle}
          aria-label="User menu"
        >
          {userAvatar ? (
            <img src={userAvatar} alt={userName} className="user-avatar" />
          ) : (
            <div className="user-avatar-placeholder">{initials}</div>
          )}
        </button>
      </div>
      {dropdown}
      {showTagManagement && (
        <TagManagementDialog onClose={() => setShowTagManagement(false)} />
      )}
      {showShortcutSettings && (
        <ShortcutSettingsDialog onClose={() => setShowShortcutSettings(false)} />
      )}

      <style>{`
        .user-menu {
          position: relative;
          z-index: 10000;
          -webkit-app-region: no-drag;
          pointer-events: auto;
        }

        .user-menu-trigger {
          display: flex;
          align-items: center;
          justify-content: center;
          width: 36px;
          height: 36px;
          padding: 0;
          background: transparent;
          border: none;
          border-radius: 50%;
          cursor: pointer;
          transition: opacity 0.2s;
          -webkit-app-region: no-drag;
          pointer-events: auto;
        }

        .user-menu-trigger:hover {
          opacity: 0.8;
        }

        .user-avatar {
          width: 32px;
          height: 32px;
          border-radius: 50%;
          object-fit: cover;
        }

        .user-avatar-placeholder {
          width: 32px;
          height: 32px;
          border-radius: 50%;
          background: var(--accent);
          color: var(--text-on-accent);
          font-size: 14px;
          font-weight: 600;
          display: flex;
          align-items: center;
          justify-content: center;
        }

        .user-menu-dropdown {
          position: fixed;
          min-width: 260px;
          padding: var(--space-2) 0;
          background: var(--bg-elevated);
          border: 1px solid var(--border-subtle);
          border-radius: var(--radius-xl);
          box-shadow: var(--shadow-lg);
          overflow: hidden;
          -webkit-app-region: no-drag;
          pointer-events: auto;
          z-index: 99999;
        }

        .user-menu-header {
          display: flex;
          align-items: center;
          gap: var(--space-3);
          padding: var(--space-2) var(--space-4) var(--space-3);
        }

        /* 이름표 + 조작이 한 줄에 서는 자리 (테마 세그먼트). */
        .user-menu-field {
          display: flex;
          align-items: center;
          justify-content: space-between;
          gap: var(--space-3);
          padding: var(--space-2) var(--space-4);
        }

        .user-menu-field-label {
          font: var(--type-meta);
          color: var(--text-secondary);
        }

        .user-avatar-large {
          width: 40px;
          height: 40px;
          border-radius: 50%;
          object-fit: cover;
        }

        .user-avatar-placeholder-large {
          width: 40px;
          height: 40px;
          border-radius: 50%;
          background: var(--accent);
          color: var(--text-on-accent);
          font-size: 18px;
          font-weight: 600;
          display: flex;
          align-items: center;
          justify-content: center;
        }

        .user-info {
          display: flex;
          flex-direction: column;
          gap: 2px;
          overflow: hidden;
        }

        .user-name {
          font: var(--type-label);
          letter-spacing: var(--type-label-tracking);
          color: var(--text-primary);
          white-space: nowrap;
          overflow: hidden;
          text-overflow: ellipsis;
        }

        .user-email {
          font: var(--type-meta);
          color: var(--text-tertiary);
          white-space: nowrap;
          overflow: hidden;
          text-overflow: ellipsis;
        }

        .user-menu-about {
          display: flex;
          flex-direction: column;
          gap: var(--space-2);
          padding: var(--space-2) var(--space-4);
        }

        .user-menu-version {
          display: flex;
          align-items: baseline;
          justify-content: space-between;
          font: var(--type-meta);
          color: var(--text-secondary);
        }

        .user-menu-version-number {
          font: var(--type-mono);
          font-variant-numeric: tabular-nums;
          color: var(--text-tertiary);
        }

        .user-menu-update-btn {
          align-self: flex-start;
          padding: 5px var(--space-3);
          border-radius: var(--radius-md);
          font: var(--type-control);
          letter-spacing: var(--type-control-tracking);
          cursor: pointer;
          background: var(--bg-tertiary);
          border: none;
          color: var(--text-secondary);
          transition: all var(--transition-fast);
        }

        .user-menu-update-btn:hover:not(:disabled) {
          background: var(--bg-hover);
          color: var(--text-primary);
        }

        .user-menu-update-btn:disabled {
          opacity: 0.6;
          cursor: not-allowed;
        }

        .user-menu-update-status {
          margin: 0;
          font: var(--type-meta);
          color: var(--text-tertiary);
        }

        .user-menu-update-status.is-error {
          color: var(--danger);
        }

        .user-menu-divider {
          height: 1px;
          background: var(--border-subtle);
          margin: var(--space-2) var(--space-4);
        }

        .user-menu-item {
          display: flex;
          align-items: center;
          gap: var(--space-3);
          width: 100%;
          padding: var(--space-2) var(--space-4);
          min-height: 36px;
          font: var(--type-meta);
          font-size: var(--text-base);
          color: var(--text-secondary);
          background: transparent;
          border: none;
          cursor: pointer;
          transition: all var(--transition-fast);
          text-align: left;
          -webkit-app-region: no-drag;
          pointer-events: auto;
        }

        .user-menu-item:hover {
          background: var(--bg-hover);
          color: var(--text-primary);
        }

        .user-menu-item svg {
          flex-shrink: 0;
        }

        .user-menu-item-key {
          margin-left: auto;
          padding: 1px 6px;
          border-radius: var(--radius-sm);
          font: var(--type-caption);
          font-family: var(--font-mono);
          color: var(--text-tertiary);
          background: var(--bg-tertiary);
        }
      `}</style>
    </>
  )
}
