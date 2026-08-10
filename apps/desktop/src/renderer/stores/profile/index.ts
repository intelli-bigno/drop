import { create } from 'zustand'
import { supabase } from '../../lib/supabase'
import { useAuthStore } from '../auth'

interface ProfileState {
  hasPin: boolean
  isLoading: boolean

  loadProfile: () => Promise<void>
  setPin: (pin: string) => Promise<void>
  verifyPin: (pin: string) => Promise<boolean>
  removePin: () => Promise<void>
}

// PIN 해시는 서버(bcrypt)에서만 생성·검증 — 클라이언트는 평문 PIN을 RPC로만 전달
export const useProfileStore = create<ProfileState>()((set) => ({
  hasPin: false,
  isLoading: true,

  loadProfile: async () => {
    const user = useAuthStore.getState().user
    if (!user) {
      set({ isLoading: false })
      return
    }

    const { data, error } = await supabase.rpc('has_note_pin')

    if (error) {
      console.error('[profile] loadProfile failed', error)
    }

    set({
      hasPin: Boolean(data),
      isLoading: false,
    })
  },

  setPin: async (pin: string) => {
    const user = useAuthStore.getState().user
    if (!user) throw new Error('Not authenticated')

    const { error } = await supabase.rpc('set_note_pin', { p_pin: pin })

    if (error) {
      console.error('[profile] setPin failed', error)
      throw error
    }

    set({ hasPin: true })
  },

  verifyPin: async (pin: string) => {
    const user = useAuthStore.getState().user
    if (!user) return false

    const { data, error } = await supabase.rpc('verify_note_pin', { p_pin: pin })

    if (error) {
      console.error('[profile] verifyPin failed', error)
      return false
    }

    return data === true
  },

  removePin: async () => {
    const user = useAuthStore.getState().user
    if (!user) return

    await supabase.from('user_profiles').update({ pin_hash: null }).eq('user_id', user.id)

    set({ hasPin: false })
  },
}))
