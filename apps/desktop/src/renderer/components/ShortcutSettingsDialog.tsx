import { useCallback, useEffect, useState } from 'react'
import { acceleratorFromKeyEvent, formatAccelerator } from '../../shared/shortcuts'
import {
  describeShortcutState,
  handleShortcutSettingsEscape,
  isDefaultShortcut,
  type QuickCaptureShortcutState,
} from '../lib/shortcut-settings'

interface Props {
  onClose: () => void
}

/** 전역 퀵캡처 단축키 설정 (BRU-84). */
export function ShortcutSettingsDialog({ onClose }: Props) {
  const [state, setState] = useState<QuickCaptureShortcutState | null>(null)
  const [recording, setRecording] = useState(false)
  const [pending, setPending] = useState<string | null>(null)
  const [error, setError] = useState<string | null>(null)
  const [saving, setSaving] = useState(false)

  useEffect(() => {
    void window.api.settings.getQuickCaptureShortcut().then(setState)
  }, [])

  const apply = useCallback(async (accelerator: string | null) => {
    setSaving(true)
    setError(null)
    try {
      const result = await window.api.settings.setQuickCaptureShortcut(accelerator)
      setState(result.state)
      if (!result.ok) setError(result.error ?? '단축키를 적용하지 못했습니다.')
      else setPending(null)
    } finally {
      setSaving(false)
      setRecording(false)
    }
  }, [])

  // Esc는 포커스가 다이얼로그 안에 없어도 이 다이얼로그의 것이다 — SearchDialog와
  // 같이 캡처 단계에서 먹고, NoteFeed 전역 핸들러까지 내려가지 않게 한다 (BRU-126).
  // 녹음 중에는 나머지 키도 가로챈다 — 다른 단축키가 먼저 먹으면 조합을 못 잡는다.
  useEffect(() => {
    const onKeyDown = (event: KeyboardEvent) => {
      const escape = handleShortcutSettingsEscape(event, recording)
      if (escape === 'cancelRecording') {
        setRecording(false)
        setPending(null)
        return
      }
      if (escape === 'close') {
        onClose()
        return
      }
      if (!recording) return

      event.preventDefault()
      event.stopPropagation()

      const accelerator = acceleratorFromKeyEvent({
        key: event.key,
        code: event.code,
        metaKey: event.metaKey,
        ctrlKey: event.ctrlKey,
        altKey: event.altKey,
        shiftKey: event.shiftKey,
      })

      // 수식키만 눌린 중간 상태는 조용히 넘긴다 — 아직 조합이 완성되지 않았다.
      if (accelerator) {
        setPending(accelerator)
        void apply(accelerator)
      }
    }

    window.addEventListener('keydown', onKeyDown, true)
    return () => window.removeEventListener('keydown', onKeyDown, true)
  }, [recording, apply, onClose])

  const handleBackdropClick = (event: React.MouseEvent) => {
    if (event.target === event.currentTarget) onClose()
  }

  const status = state ? describeShortcutState(state, window.api.platform) : null
  const displayed = pending ?? state?.accelerator ?? null

  return (
    <div className="tag-management-backdrop" onClick={handleBackdropClick}>
      <div className="tag-management-dialog shortcut-settings-dialog">
        <div className="tag-management-header">
          <h2 className="tag-management-title">전역 단축키</h2>
          <button className="tag-management-close" onClick={onClose} aria-label="닫기">
            ✕
          </button>
        </div>

        <div className="shortcut-settings-body">
          <p className="shortcut-settings-label">퀵캡처 열기</p>

          <button
            type="button"
            className={`shortcut-settings-recorder ${recording ? 'is-recording' : ''}`}
            onClick={() => {
              setError(null)
              setRecording((value) => !value)
            }}
            disabled={saving}
          >
            {recording
              ? '조합을 누르세요… (ESC로 취소)'
              : displayed
                ? formatAccelerator(displayed, window.api.platform)
                : '등록 안 됨'}
          </button>

          {status && (
            <p
              className={`shortcut-settings-status ${status.tone === 'error' ? 'is-error' : ''}`}
            >
              {status.text}
            </p>
          )}

          {error && <p className="shortcut-settings-status is-error">{error}</p>}

          <div className="shortcut-settings-actions">
            <button
              type="button"
              className="shortcut-settings-reset"
              onClick={() => void apply(null)}
              disabled={saving || (state !== null && isDefaultShortcut(state))}
            >
              기본값으로 되돌리기
            </button>
          </div>

          <p className="shortcut-settings-hint">
            수식키(⌘ ⌃ ⌥ ⇧)를 최소 하나 포함해야 합니다. 다른 앱이 이미 쓰고 있는 조합은 등록되지
            않고, 그 사실이 위에 표시됩니다.
          </p>
        </div>
      </div>
    </div>
  )
}
