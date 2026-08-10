import { useToastStore } from '../stores/toast'

export function Toaster() {
  const toasts = useToastStore((s) => s.toasts)
  const dismissToast = useToastStore((s) => s.dismissToast)

  if (toasts.length === 0) return null

  return (
    <div className="toaster" role="status" aria-live="polite">
      {toasts.map((toast) => (
        <div
          key={toast.id}
          className={`toast ${toast.variant === 'error' ? 'toast-error' : ''}`}
          onClick={() => dismissToast(toast.id)}
        >
          <span className="toast-message">{toast.message}</span>
          {toast.actionLabel && (
            <button
              className="toast-action"
              onClick={(e) => {
                e.stopPropagation()
                toast.onAction?.()
                dismissToast(toast.id)
              }}
            >
              {toast.actionLabel}
            </button>
          )}
        </div>
      ))}
    </div>
  )
}
