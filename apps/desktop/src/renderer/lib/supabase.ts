import { createClient } from '@supabase/supabase-js'
import { createAsyncValueCache } from './async-value-cache'

// 환경 변수에서 Supabase 설정 로드
// VITE_SUPABASE_URL과 VITE_SUPABASE_ANON_KEY는 .env.local 또는 .env.remote에서 설정
const supabaseUrl = import.meta.env.VITE_SUPABASE_URL
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY

if (!supabaseUrl || !supabaseAnonKey) {
  throw new Error(
    'VITE_SUPABASE_URL and VITE_SUPABASE_ANON_KEY must be set.\n' +
      'Copy .env.example to .env.local and fill in the values.'
  )
}

export const supabase = createClient(supabaseUrl, supabaseAnonKey)

// Storage 헬퍼
export async function uploadAttachment(
  file: File,
  noteId: string
): Promise<{ path: string; error: Error | null }> {
  // Get current user for storage path
  const {
    data: { user },
  } = await supabase.auth.getUser()
  if (!user) {
    return { path: '', error: new Error('User not authenticated') }
  }

  const fileExt = file.name.split('.').pop()
  // Storage path: {user_id}/{note_id}/{filename}
  const fileName = `${user.id}/${noteId}/${crypto.randomUUID()}.${fileExt}`

  const { error } = await supabase.storage.from('attachments').upload(fileName, file)

  if (error) {
    return { path: '', error }
  }

  return { path: fileName, error: null }
}

export function getAttachmentUrl(storagePath: string): string {
  const { data } = supabase.storage.from('attachments').getPublicUrl(storagePath)
  return data.publicUrl
}

const SIGNED_URL_EXPIRES_IN_SECONDS = 60 * 60
// 발급받은 URL은 만료보다 넉넉히 먼저 버린다 — 만료 직전 URL을 <img>에 물리면
// 로드 중에 죽는다.
const SIGNED_URL_CACHE_TTL_MS = 45 * 60 * 1000

async function createSignedAttachmentUrl(storagePath: string): Promise<string | null> {
  const { data, error } = await supabase.storage
    .from('attachments')
    .createSignedUrl(storagePath, SIGNED_URL_EXPIRES_IN_SECONDS)

  if (error) {
    console.error('[attachments] signed url error', error)
    return null
  }

  return data?.signedUrl ?? null
}

/**
 * 같은 첨부의 서명 URL을 되풀이해 발급받지 않는다 (BRU-79).
 *
 * 카드를 펼칠 때마다 `AttachmentList`가 새로 마운트되고, 마운트마다 첨부 하나당
 * 발급 요청이 한 번씩 나갔다. 전체 펼치기를 켜면 그 요청이 첨부 수만큼 동시에
 * 나가고, j/k로 한 칸 넘기기만 해도 방금 받은 URL을 버리고 또 받았다.
 */
const signedUrlCache = createAsyncValueCache(createSignedAttachmentUrl, {
  ttlMs: SIGNED_URL_CACHE_TTL_MS,
})

export function getSignedAttachmentUrl(storagePath: string): Promise<string | null> {
  return signedUrlCache.get(storagePath)
}

/** 로드에 실패해 다시 받아야 할 때 — 캐시된 URL을 버린다 */
export function invalidateSignedAttachmentUrl(storagePath: string): void {
  signedUrlCache.invalidate(storagePath)
}
