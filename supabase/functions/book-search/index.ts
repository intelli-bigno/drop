// 도서 검색 프록시 — 알라딘/네이버/카카오 API 키를 클라이언트에 싣지 않기 위한 Edge Function
// 인증: 사용자 JWT
// 요청: GET ?q=검색어  또는 POST { query }
// 응답: { items: UnifiedBookResult[] } (ISBN13 기준 중복 제거, 알라딘 > 네이버 > 카카오 우선)
import { createClient } from 'jsr:@supabase/supabase-js@2'

interface UnifiedBookResult {
  isbn13: string
  isbn10: string | null
  title: string
  author: string
  publisher: string
  pubDate: string | null
  coverUrl: string | null
  description: string | null
  provider: 'aladin' | 'naver' | 'kakao'
}

Deno.serve(async (req) => {
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

  let query = new URL(req.url).searchParams.get('q') ?? ''
  if (!query && req.method === 'POST') {
    const body = await req.json().catch(() => ({}))
    query = body.query ?? ''
  }
  query = query.trim()
  if (!query) return json({ items: [] })

  const [aladin, naver, kakao] = await Promise.all([
    searchAladin(query).catch((e) => logAndEmpty('aladin', e)),
    searchNaver(query).catch((e) => logAndEmpty('naver', e)),
    searchKakao(query).catch((e) => logAndEmpty('kakao', e)),
  ])

  const seen = new Set<string>()
  const items: UnifiedBookResult[] = []
  for (const item of [...aladin, ...naver, ...kakao]) {
    if (!item.isbn13 || seen.has(item.isbn13)) continue
    seen.add(item.isbn13)
    items.push(item)
    if (items.length >= 30) break
  }

  return json({ items })
})

function logAndEmpty(provider: string, e: unknown): UnifiedBookResult[] {
  console.error(`[book-search] ${provider} failed:`, e)
  return []
}

async function searchAladin(query: string): Promise<UnifiedBookResult[]> {
  const key = Deno.env.get('ALADIN_TTB_KEY')
  if (!key) return []
  const url = new URL('https://www.aladin.co.kr/ttb/api/ItemSearch.aspx')
  url.search = new URLSearchParams({
    ttbkey: key,
    Query: query,
    QueryType: 'Keyword',
    MaxResults: '20',
    start: '1',
    SearchTarget: 'Book',
    output: 'js',
    Version: '20131101',
  }).toString()
  const res = await fetch(url)
  const data = await res.json()
  return ((data.item as unknown[]) ?? []).map((raw) => {
    const item = raw as Record<string, unknown>
    return {
      isbn13: String(item.isbn13 ?? ''),
      isbn10: item.isbn ? String(item.isbn) : null,
      title: String(item.title ?? ''),
      author: String(item.author ?? ''),
      publisher: String(item.publisher ?? ''),
      pubDate: item.pubDate ? String(item.pubDate) : null,
      coverUrl: item.cover ? String(item.cover) : null,
      description: item.description ? String(item.description) : null,
      provider: 'aladin' as const,
    }
  })
}

async function searchNaver(query: string): Promise<UnifiedBookResult[]> {
  const clientId = Deno.env.get('NAVER_CLIENT_ID')
  const clientSecret = Deno.env.get('NAVER_CLIENT_SECRET')
  if (!clientId || !clientSecret) return []
  const url = new URL('https://openapi.naver.com/v1/search/book.json')
  url.search = new URLSearchParams({ query, display: '20' }).toString()
  const res = await fetch(url, {
    headers: {
      'X-Naver-Client-Id': clientId,
      'X-Naver-Client-Secret': clientSecret,
    },
  })
  const data = await res.json()
  return ((data.items as unknown[]) ?? []).map((raw) => {
    const item = raw as Record<string, unknown>
    return {
      isbn13: String(item.isbn ?? '').replace(/[^0-9X]/g, '').slice(-13),
      isbn10: null,
      title: stripTags(String(item.title ?? '')),
      author: stripTags(String(item.author ?? '')),
      publisher: stripTags(String(item.publisher ?? '')),
      pubDate: item.pubdate ? String(item.pubdate) : null,
      coverUrl: item.image ? String(item.image) : null,
      description: item.description ? stripTags(String(item.description)) : null,
      provider: 'naver' as const,
    }
  })
}

async function searchKakao(query: string): Promise<UnifiedBookResult[]> {
  const key = Deno.env.get('KAKAO_REST_API_KEY')
  if (!key) return []
  const url = new URL('https://dapi.kakao.com/v3/search/book')
  url.search = new URLSearchParams({ query, size: '20' }).toString()
  const res = await fetch(url, {
    headers: { Authorization: `KakaoAK ${key}` },
  })
  const data = await res.json()
  return ((data.documents as unknown[]) ?? []).map((raw) => {
    const item = raw as Record<string, unknown>
    const isbns = String(item.isbn ?? '').split(' ')
    const isbn13 = isbns.find((v) => v.length === 13) ?? ''
    const isbn10 = isbns.find((v) => v.length === 10) ?? null
    return {
      isbn13,
      isbn10,
      title: String(item.title ?? ''),
      author: ((item.authors as string[]) ?? []).join(', '),
      publisher: String(item.publisher ?? ''),
      pubDate: item.datetime ? String(item.datetime).slice(0, 10) : null,
      coverUrl: item.thumbnail ? String(item.thumbnail) : null,
      description: item.contents ? String(item.contents) : null,
      provider: 'kakao' as const,
    }
  })
}

function stripTags(s: string): string {
  return s.replace(/<[^>]*>/g, '')
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  })
}
