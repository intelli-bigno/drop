import { create } from 'zustand'

export interface Toast {
  id: number
  message: string
  variant?: 'default' | 'error'
  actionLabel?: string
  onAction?: () => void
  /** 자동 닫힘까지의 시간 (ms). 기본 4000 */
  duration?: number
}

interface ToastState {
  toasts: Toast[]
  showToast: (toast: Omit<Toast, 'id'>) => number
  dismissToast: (id: number) => void
}

let nextToastId = 1
const timers = new Map<number, ReturnType<typeof setTimeout>>()

export const useToastStore = create<ToastState>()((set, get) => ({
  toasts: [],

  showToast: (toast) => {
    const id = nextToastId++
    set((state) => ({ toasts: [...state.toasts, { ...toast, id }] }))

    const duration = toast.duration ?? 4000
    const timer = setTimeout(() => {
      get().dismissToast(id)
    }, duration)
    timers.set(id, timer)

    return id
  },

  dismissToast: (id) => {
    const timer = timers.get(id)
    if (timer) {
      clearTimeout(timer)
      timers.delete(id)
    }
    set((state) => ({ toasts: state.toasts.filter((t) => t.id !== id) }))
  },
}))
