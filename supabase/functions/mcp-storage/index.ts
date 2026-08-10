// MCP 서버용 스토리지 프록시 — anon 스토리지 정책 제거 후 유일한 MCP 스토리지 경로
// 인증: X-Drop-Token 헤더 (MCP API 키) → get_user_id_by_mcp_key RPC로 검증
// 스토리지 작업은 service role로 수행하되, 경로를 {user_id}/ 프리픽스로 강제
// 요청(POST JSON):
//   { action: 'upload', path, contentBase64, contentType }
//   { action: 'sign', path, expiresIn? }
//   { action: 'delete', path }
import { createClient } from 'jsr:@supabase/supabase-js@2'

const BUCKET = 'attachments'
const MAX_UPLOAD_SIZE = 25 * 1024 * 1024
const DEFAULT_SIGN_EXPIRY = 3600

Deno.serve(async (req) => {
  if (req.method !== 'POST') {
    return json({ error: 'Method not allowed' }, 405)
  }

  const apiKey = req.headers.get('X-Drop-Token')
  if (!apiKey) {
    return json({ error: 'Missing X-Drop-Token header' }, 401)
  }

  const anonClient = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_ANON_KEY')!
  )
  const { data: userId, error: rpcError } = await anonClient.rpc(
    'get_user_id_by_mcp_key',
    { api_key: apiKey }
  )
  if (rpcError || !userId) {
    return json({ error: 'Invalid API key' }, 401)
  }

  const serviceClient = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  )

  const body = await req.json().catch(() => null)
  if (!body || typeof body.path !== 'string') {
    return json({ error: 'Invalid request body' }, 400)
  }

  // 경로는 반드시 본인 폴더({user_id}/...) 아래여야 함
  const path = body.path.replace(/^\/+/, '')
  if (!path.startsWith(`${userId}/`) || path.includes('..')) {
    return json({ error: 'Path outside your folder' }, 403)
  }

  const storage = serviceClient.storage.from(BUCKET)

  switch (body.action) {
    case 'upload': {
      if (typeof body.contentBase64 !== 'string') {
        return json({ error: 'Missing contentBase64' }, 400)
      }
      const bytes = base64Decode(body.contentBase64)
      if (bytes.length > MAX_UPLOAD_SIZE) {
        return json({ error: 'File exceeds 25MB limit' }, 413)
      }
      const { error } = await storage.upload(path, bytes, {
        contentType: body.contentType ?? 'application/octet-stream',
        upsert: false,
      })
      if (error) return json({ error: error.message }, 500)
      const { data: signed } = await storage.createSignedUrl(path, DEFAULT_SIGN_EXPIRY)
      return json({ path, signedUrl: signed?.signedUrl ?? null })
    }
    case 'sign': {
      const expiresIn = clampExpiry(body.expiresIn)
      const { data, error } = await storage.createSignedUrl(path, expiresIn)
      if (error) return json({ error: error.message }, 500)
      return json({ path, signedUrl: data.signedUrl })
    }
    case 'delete': {
      const { error } = await storage.remove([path])
      if (error) return json({ error: error.message }, 500)
      return json({ path, deleted: true })
    }
    default:
      return json({ error: 'Unknown action' }, 400)
  }
})

function clampExpiry(value: unknown): number {
  const n = typeof value === 'number' ? value : DEFAULT_SIGN_EXPIRY
  return Math.min(Math.max(n, 60), 24 * 3600)
}

function base64Decode(input: string): Uint8Array {
  const binary = atob(input)
  const bytes = new Uint8Array(binary.length)
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i)
  }
  return bytes
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  })
}
