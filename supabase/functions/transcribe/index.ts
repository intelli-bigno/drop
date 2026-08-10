// Whisper 전사 프록시 — OpenAI 키를 클라이언트에 싣지 않기 위한 Edge Function
// 인증: 사용자 JWT (Authorization: Bearer <access_token>)
// 요청: multipart/form-data, field "file" (audio)
// 응답: { text: string }
import { createClient } from 'jsr:@supabase/supabase-js@2'

const MAX_FILE_SIZE = 25 * 1024 * 1024 // OpenAI Whisper 제한

Deno.serve(async (req) => {
  if (req.method !== 'POST') {
    return json({ error: 'Method not allowed' }, 405)
  }

  const authHeader = req.headers.get('Authorization') ?? ''
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_ANON_KEY')!,
    { global: { headers: { Authorization: authHeader } } }
  )
  const { data: userData, error: userError } = await supabase.auth.getUser()
  if (userError || !userData.user) {
    return json({ error: 'Unauthorized' }, 401)
  }

  const openaiKey = Deno.env.get('OPENAI_API_KEY')
  if (!openaiKey) {
    return json({ error: 'OPENAI_API_KEY not configured' }, 500)
  }

  const form = await req.formData()
  const file = form.get('file')
  if (!(file instanceof File)) {
    return json({ error: 'Missing "file" field' }, 400)
  }
  if (file.size > MAX_FILE_SIZE) {
    return json({ error: 'File exceeds 25MB limit' }, 413)
  }

  const upstream = new FormData()
  upstream.append('file', file, file.name || 'audio.m4a')
  upstream.append('model', 'whisper-1')
  const language = form.get('language')
  if (typeof language === 'string' && language) {
    upstream.append('language', language)
  }

  const res = await fetch('https://api.openai.com/v1/audio/transcriptions', {
    method: 'POST',
    headers: { Authorization: `Bearer ${openaiKey}` },
    body: upstream,
  })

  if (!res.ok) {
    const detail = await res.text()
    console.error('[transcribe] OpenAI error', res.status, detail)
    return json({ error: 'Transcription failed', status: res.status }, 502)
  }

  const result = await res.json()
  return json({ text: result.text ?? '' })
})

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  })
}
