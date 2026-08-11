import { useState, useRef, useEffect } from 'react'
import { createPortal } from 'react-dom'
import { useAuthStore } from '../stores/auth'
import { supabase } from '../lib/supabase'
import { useToastStore } from '../stores/toast'
import { decideMcpTokenAction, isPlaintextToken } from '../lib/mcp-token'
import { TagManagementDialog } from './TagManagementDialog'

export function UserMenu() {
  const { user, signOut } = useAuthStore()
  const [isOpen, setIsOpen] = useState(false)
  const [tokenCopied, setTokenCopied] = useState(false)
  const [showTagManagement, setShowTagManagement] = useState(false)
  const menuRef = useRef<HTMLDivElement>(null)
  const triggerRef = useRef<HTMLButtonElement>(null)
  const [dropdownPos, setDropdownPos] = useState({ top: 0, right: 0 })

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

        <button className="user-menu-item" onClick={handleOpenTagManagement}>
          <svg
            width="16"
            height="16"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            strokeWidth="2"
            strokeLinecap="round"
            strokeLinejoin="round"
          >
            <path d="M20.59 13.41l-7.17 7.17a2 2 0 0 1-2.83 0L2 12V2h10l8.59 8.59a2 2 0 0 1 0 2.82z" />
            <line x1="7" y1="7" x2="7.01" y2="7" />
          </svg>
          태그 관리
        </button>

        <button className="user-menu-item" onClick={handleCopyMcpToken}>
          <svg
            width="16"
            height="16"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            strokeWidth="2"
            strokeLinecap="round"
            strokeLinejoin="round"
          >
            <rect x="9" y="9" width="13" height="13" rx="2" ry="2" />
            <path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1" />
          </svg>
          {tokenCopied ? 'Copied!' : 'Copy MCP Token'}
        </button>

        <button className="user-menu-item" onClick={handleSignOut}>
          <svg
            width="16"
            height="16"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            strokeWidth="2"
            strokeLinecap="round"
            strokeLinejoin="round"
          >
            <path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4" />
            <polyline points="16 17 21 12 16 7" />
            <line x1="21" y1="12" x2="9" y2="12" />
          </svg>
          Sign out
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
          background: linear-gradient(135deg, var(--accent) 0%, #0d9488 100%);
          color: #fff;
          font-size: 14px;
          font-weight: 600;
          display: flex;
          align-items: center;
          justify-content: center;
        }

        .user-menu-dropdown {
          position: fixed;
          min-width: 240px;
          background: var(--bg-elevated);
          border: 1px solid #3a3a3a;
          border-radius: 12px;
          box-shadow: 0 8px 32px rgba(0, 0, 0, 0.4);
          overflow: hidden;
          -webkit-app-region: no-drag;
          pointer-events: auto;
          z-index: 99999;
        }

        .user-menu-header {
          display: flex;
          align-items: center;
          gap: 12px;
          padding: 16px;
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
          background: linear-gradient(135deg, var(--accent) 0%, #0d9488 100%);
          color: #fff;
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
          font-size: 14px;
          font-weight: 600;
          color: #fff;
          white-space: nowrap;
          overflow: hidden;
          text-overflow: ellipsis;
        }

        .user-email {
          font-size: 12px;
          color: #888;
          white-space: nowrap;
          overflow: hidden;
          text-overflow: ellipsis;
        }

        .user-menu-divider {
          height: 1px;
          background: #3a3a3a;
          margin: 0 8px;
        }

        .user-menu-item {
          display: flex;
          align-items: center;
          gap: 12px;
          width: 100%;
          padding: 12px 16px;
          font-size: 14px;
          color: #ccc;
          background: transparent;
          border: none;
          cursor: pointer;
          transition: all 0.2s;
          text-align: left;
          -webkit-app-region: no-drag;
          pointer-events: auto;
        }

        .user-menu-item:hover {
          background: #3a3a3a;
          color: #fff;
        }

        .user-menu-item svg {
          flex-shrink: 0;
        }
      `}</style>
    </>
  )
}
