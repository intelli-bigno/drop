import { useEffect, useRef } from 'react'
import { FOCUSABLE_SELECTOR, nextFocusIndex } from '../lib/focus-trap'

interface Props {
  title: string
  message: string
  confirmLabel?: string
  cancelLabel?: string
  danger?: boolean
  onConfirm: () => void
  onCancel: () => void
}

/**
 * 파괴적 액션(영구 삭제 등) 확인용 인앱 다이얼로그.
 * PinDialog와 같은 backdrop/dialog 패턴을 따른다.
 *
 * 포커스 규칙(BRU-54):
 * - 기본 포커스는 취소다. 파괴적 버튼에 포커스를 두면 Backspace+Enter 두 번에 노트가 사라진다.
 * - Tab은 다이얼로그 안에서 순환한다(포커스 트랩).
 * - Escape는 포커스가 어디에 있든 취소한다 — document 캡처 단계에서 받는다.
 * - 닫히면 열기 직전에 포커스가 있던 곳으로 되돌린다.
 */
export function ConfirmDialog({
  title,
  message,
  confirmLabel = '확인',
  cancelLabel = '취소',
  danger = false,
  onConfirm,
  onCancel,
}: Props) {
  const dialogRef = useRef<HTMLDivElement>(null)
  const cancelRef = useRef<HTMLButtonElement>(null)

  // 최신 onCancel을 리스너 재등록 없이 참조하기 위한 통로
  const onCancelRef = useRef(onCancel)
  useEffect(() => {
    onCancelRef.current = onCancel
  }, [onCancel])

  useEffect(() => {
    const previouslyFocused = document.activeElement as HTMLElement | null
    cancelRef.current?.focus()
    return () => {
      previouslyFocused?.focus?.()
    }
  }, [])

  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      // 모달이 열려 있는 동안 키보드는 다이얼로그의 것이다 — 뒤 화면 단축키로 새어 나가지 않는다.
      // 기본 동작(포커스된 버튼의 Enter/Space 활성화 등)은 막지 않는다.
      e.stopPropagation()

      if (e.key === 'Escape') {
        e.preventDefault()
        onCancelRef.current()
        return
      }
      if (e.key !== 'Tab') return

      const dialog = dialogRef.current
      if (!dialog) return
      const focusables = Array.from(dialog.querySelectorAll<HTMLElement>(FOCUSABLE_SELECTOR))
      const target = focusables[
        nextFocusIndex({
          count: focusables.length,
          currentIndex: focusables.indexOf(document.activeElement as HTMLElement),
          shiftKey: e.shiftKey,
        })
      ] as HTMLElement | undefined
      if (!target) return
      e.preventDefault()
      target.focus()
    }

    // 캡처 단계 — 포커스가 다이얼로그 밖에 있어도, 뒤 화면의 핸들러보다 먼저 받는다
    document.addEventListener('keydown', handleKeyDown, true)
    return () => document.removeEventListener('keydown', handleKeyDown, true)
  }, [])

  return (
    <div className="confirm-dialog-backdrop" onClick={onCancel}>
      <div className="confirm-dialog" ref={dialogRef} onClick={(e) => e.stopPropagation()}>
        <h3 className="confirm-dialog-title">{title}</h3>
        <p className="confirm-dialog-message">{message}</p>
        <div className="confirm-dialog-actions">
          <button ref={cancelRef} type="button" onClick={onCancel}>
            {cancelLabel}
          </button>
          <button
            type="button"
            className={danger ? 'confirm-dialog-danger' : 'confirm-dialog-primary'}
            onClick={onConfirm}
          >
            {confirmLabel}
          </button>
        </div>
      </div>
    </div>
  )
}
