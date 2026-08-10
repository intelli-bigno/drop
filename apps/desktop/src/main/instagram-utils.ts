export interface InstagramMediaItem {
  displayUrl: string
  videoUrl?: string
  typename: string
  imageBase64?: string | null
  videoBase64?: string | null
}

export interface InstagramPostData {
  shortcode: string
  displayUrl: string
  videoUrl?: string
  caption: string
  username: string
  displayName?: string
  profilePicUrl: string
  timestamp: number
  typename: string
  media: InstagramMediaItem[]
}

export const INSTAGRAM_PATH_TYPES = new Set(['p', 'reel', 'reels', 'tv'])
export const INSTAGRAM_HANDLE_PATTERN = /^[A-Za-z0-9._]{1,30}$/
export const SHORTCODE_ALPHABET =
  'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_'

export function parseInstagramUrl(
  inputUrl: string
): { shortcode: string; postUrl: string } | null {
  try {
    const url = new URL(inputUrl)
    const hostname = url.hostname.replace(/^www\./, '')
    if (hostname !== 'instagram.com' && hostname !== 'instagr.am') return null

    const parts = url.pathname.split('/').filter(Boolean)
    let type = parts[0]
    let shortcode = parts[1]

    if (type === 'share') {
      if (parts.length < 3) return null
      type = parts[1]
      shortcode = parts[2]
    }

    if (!type || !shortcode || !INSTAGRAM_PATH_TYPES.has(type)) return null
    const normalizedType = type === 'reels' ? 'reel' : type

    return {
      shortcode,
      postUrl: `https://www.instagram.com/${normalizedType}/${shortcode}/`,
    }
  } catch {
    return null
  }
}

export function decodeInstagramShortcode(shortcode: string): string | null {
  let id = 0n
  for (const char of shortcode) {
    const index = SHORTCODE_ALPHABET.indexOf(char)
    if (index === -1) return null
    id = id * 64n + BigInt(index)
  }
  return id.toString()
}

export function decodeHtmlEntities(value: string): string {
  return value
    .replace(/&#x([0-9a-fA-F]+);/g, (_, hex) => {
      const codePoint = Number.parseInt(hex, 16)
      if (Number.isNaN(codePoint)) return _
      return String.fromCodePoint(codePoint)
    })
    .replace(/&#(\d+);/g, (_, num) => {
      const codePoint = Number.parseInt(num, 10)
      if (Number.isNaN(codePoint)) return _
      return String.fromCodePoint(codePoint)
    })
    .replace(/&amp;/g, '&')
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'")
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
}

export function extractMetaContent(html: string, property: string): string | null {
  const patterns = [
    new RegExp(
      `<meta[^>]+property=["']${property}["'][^>]+content=["']([^"']+)["']`,
      'i'
    ),
    new RegExp(
      `<meta[^>]+content=["']([^"']+)["'][^>]+property=["']${property}["']`,
      'i'
    ),
  ]

  for (const pattern of patterns) {
    const match = html.match(pattern)
    if (match && match[1]) return match[1]
  }

  return null
}

export function extractMetaName(html: string, name: string): string | null {
  const patterns = [
    new RegExp(
      `<meta[^>]+name=["']${name}["'][^>]+content=["']([^"']+)["']`,
      'i'
    ),
    new RegExp(
      `<meta[^>]+content=["']([^"']+)["'][^>]+name=["']${name}["']`,
      'i'
    ),
  ]

  for (const pattern of patterns) {
    const match = html.match(pattern)
    if (match && match[1]) return match[1]
  }

  return null
}

export function extractJsonLdPayloads(html: string): unknown[] {
  const pattern =
    /<script[^>]+type=["']application\/ld\+json["'][^>]*>([\s\S]*?)<\/script>/gi
  const payloads: unknown[] = []

  let match: RegExpExecArray | null = null
  while ((match = pattern.exec(html))) {
    const raw = match[1]?.trim()
    if (!raw) continue
    try {
      const parsed = JSON.parse(raw)
      if (Array.isArray(parsed)) {
        payloads.push(...parsed)
      } else {
        payloads.push(parsed)
      }
    } catch {
      continue
    }
  }

  return payloads
}

export function collectJsonLdObjects(
  value: unknown,
  result: Record<string, unknown>[] = []
): Record<string, unknown>[] {
  if (!value) return result
  if (Array.isArray(value)) {
    for (const item of value) collectJsonLdObjects(item, result)
    return result
  }
  if (typeof value === 'object') {
    result.push(value as Record<string, unknown>)
    for (const entry of Object.values(value as Record<string, unknown>)) {
      collectJsonLdObjects(entry, result)
    }
  }
  return result
}

export function pickStringField(
  record: Record<string, unknown>,
  keys: string[]
): string | null {
  for (const key of keys) {
    const value = record[key]
    if (typeof value === 'string' && value.trim()) {
      return value
    }
  }
  return null
}

export function findValueByKey(
  value: unknown,
  keys: string[],
  depth = 0,
  maxDepth = 6
): unknown | null {
  if (value === null || value === undefined || depth > maxDepth) return null

  if (Array.isArray(value)) {
    for (const item of value) {
      const found = findValueByKey(item, keys, depth + 1, maxDepth)
      if (found) return found
    }
    return null
  }

  if (typeof value === 'object') {
    const obj = value as Record<string, unknown>
    for (const key of keys) {
      if (key in obj) return obj[key]
    }
    for (const item of Object.values(obj)) {
      const found = findValueByKey(item, keys, depth + 1, maxDepth)
      if (found) return found
    }
  }

  return null
}

export function extractCaptionFromJsonLd(payloads: unknown[]): string {
  const objects = collectJsonLdObjects(payloads)
  const allowedTypes = new Set([
    'ImageObject',
    'VideoObject',
    'SocialMediaPosting',
    'Article',
    'NewsArticle',
  ])

  for (const obj of objects) {
    const typeValue = obj['@type']
    if (typeof typeValue === 'string' && !allowedTypes.has(typeValue)) {
      continue
    }
    const caption = pickStringField(obj, ['caption', 'articleBody', 'description'])
    if (caption) return decodeHtmlEntities(caption)
  }

  const fallback = findValueByKey(payloads, ['caption', 'articleBody', 'description'])
  if (typeof fallback === 'string') return decodeHtmlEntities(fallback)

  return ''
}

export function extractAuthorFromJsonLd(payloads: unknown[]): string {
  const objects = collectJsonLdObjects(payloads)
  const stripAt = (value: string) => value.trim().replace(/^@/, '')

  for (const obj of objects) {
    const author = obj.author
    if (!author) continue
    if (typeof author === 'string' && author.trim()) return stripAt(author)
    if (Array.isArray(author)) {
      for (const item of author) {
        if (typeof item === 'string' && item.trim()) return stripAt(item)
        if (item && typeof item === 'object') {
          const name = pickStringField(item as Record<string, unknown>, [
            'name',
            'alternateName',
          ])
          if (name) return stripAt(name)
        }
      }
    }
    if (typeof author === 'object') {
      const name = pickStringField(author as Record<string, unknown>, [
        'name',
        'alternateName',
      ])
      if (name) return stripAt(name)
    }
  }

  return ''
}

export function extractHandleFromText(text: string): string | null {
  if (!text) return null
  const cleaned = decodeHtmlEntities(text).trim()
  if (!cleaned) return null

  if (INSTAGRAM_HANDLE_PATTERN.test(cleaned)) return cleaned

  const onInstagramMatch = cleaned.match(/-\\s*([A-Za-z0-9._]{1,30})\\s+on\\s+Instagram/i)
  if (onInstagramMatch?.[1]) return onInstagramMatch[1]

  const atMatch = cleaned.match(/@([A-Za-z0-9._]{1,30})/)
  if (atMatch?.[1]) return atMatch[1]

  const tokens = cleaned.split(/\s+/)
  for (const token of tokens) {
    const normalized = token.replace(/[^A-Za-z0-9._]/g, '')
    if (INSTAGRAM_HANDLE_PATTERN.test(normalized)) return normalized
  }

  return null
}

export function cleanInstagramCaption(text: string): string {
  const trimmed = decodeHtmlEntities(text).trim()
  if (!trimmed) return ''

  const likesPrefix = /^\d[\d,.Kk]*\s+likes?,\s+\d[\d,.Kk]*\s+comments?\s+-\s+/i
  if (likesPrefix.test(trimmed)) {
    const quoted = trimmed.match(/:\s*[""]([\s\S]*)[""]\.?$/)
    if (quoted?.[1]) return quoted[1].trim()

    const withoutPrefix = trimmed.replace(likesPrefix, '')
    const tail = withoutPrefix.replace(/^[^:]*:\s*/i, '')
    return tail.replace(/^[""]|[""]$/g, '').trim()
  }

  if (/on Instagram/i.test(trimmed)) {
    const quoted = trimmed.match(/:\s*[""]([\s\S]*)[""]\.?$/)
    if (quoted?.[1]) return quoted[1].trim()
  }

  return trimmed
}

export function extractJsonAfterMarker(html: string, marker: string): unknown | null {
  const markerIndex = html.indexOf(marker)
  if (markerIndex === -1) return null

  const startIndex = html.indexOf('{', markerIndex)
  if (startIndex === -1) return null

  let depth = 0
  let inString = false
  let escapeNext = false

  for (let i = startIndex; i < html.length; i += 1) {
    const char = html[i]

    if (inString) {
      if (escapeNext) {
        escapeNext = false
        continue
      }
      if (char === '\\') {
        escapeNext = true
        continue
      }
      if (char === '"') {
        inString = false
      }
      continue
    }

    if (char === '"') {
      inString = true
      continue
    }

    if (char === '{') {
      depth += 1
    } else if (char === '}') {
      depth -= 1
      if (depth === 0) {
        const jsonText = html.slice(startIndex, i + 1)
        try {
          return JSON.parse(jsonText)
        } catch {
          return null
        }
      }
    }
  }

  return null
}

export function extractJsonFromScript(html: string, id: string): unknown | null {
  const pattern = new RegExp(
    `<script[^>]+id=["']${id}["'][^>]*>([\\s\\S]*?)<\\/script>`,
    'i'
  )
  const match = html.match(pattern)
  if (!match || !match[1]) return null

  try {
    return JSON.parse(match[1])
  } catch {
    return null
  }
}

export function getValueAtPath(
  value: unknown,
  path: Array<string | number>
): unknown | null {
  let current: unknown = value

  for (const segment of path) {
    if (current === null || current === undefined) return null
    if (typeof segment === 'number') {
      if (!Array.isArray(current)) return null
      current = current[segment]
      continue
    }
    if (typeof current !== 'object') return null
    current = (current as Record<string, unknown>)[segment]
  }

  return current ?? null
}

export function findShortcodeMedia(payload: unknown): unknown | null {
  if (!payload) return null

  const candidates: Array<Array<string | number>> = [
    ['entry_data', 'PostPage', 0, 'graphql', 'shortcode_media'],
    ['graphql', 'shortcode_media'],
    ['data', 'shortcode_media'],
    ['data', 'xdt_shortcode_media'],
    ['props', 'pageProps', 'graphql', 'shortcode_media'],
    ['props', 'pageProps', 'data', 'shortcode_media'],
    ['props', 'pageProps', 'data', 'xdt_shortcode_media'],
  ]

  for (const path of candidates) {
    const found = getValueAtPath(payload, path)
    if (found) return found
  }

  const byKey = findValueByKey(payload, ['shortcode_media', 'xdt_shortcode_media'])
  if (byKey) return byKey

  const items = findValueByKey(payload, ['items'])
  if (Array.isArray(items) && items[0]) return items[0]

  return null
}

export function normalizeTypename(node: Record<string, unknown> | null): string {
  if (node && typeof node.__typename === 'string') return node.__typename
  if (node && typeof node.media_type === 'number') {
    if (node.media_type === 2) return 'GraphVideo'
    if (node.media_type === 8) return 'GraphSidecar'
  }
  if (node && node.is_video) return 'GraphVideo'
  return 'GraphImage'
}

export type ImageCandidate = {
  src?: string
  url?: string
  width?: number
  height?: number
}

export function pickBestImageUrl(candidates?: ImageCandidate[] | null): string | null {
  if (!Array.isArray(candidates) || candidates.length === 0) return null

  let best: { url: string; area: number } | null = null
  for (const candidate of candidates) {
    const url = candidate?.src ?? candidate?.url
    if (!url) continue
    const width = typeof candidate.width === 'number' ? candidate.width : 0
    const height = typeof candidate.height === 'number' ? candidate.height : 0
    const area = width && height ? width * height : 0
    if (!best || area > best.area) {
      best = { url, area }
    }
  }

  if (best?.url) return best.url
  const fallback = candidates[candidates.length - 1]
  return (fallback?.src ?? fallback?.url) || null
}

export type VideoCandidate = {
  url?: string
  width?: number
  height?: number
}

export function pickBestVideoUrl(candidates?: VideoCandidate[] | null): string | null {
  if (!Array.isArray(candidates) || candidates.length === 0) return null

  let best: { url: string; area: number } | null = null
  for (const candidate of candidates) {
    const url = candidate?.url
    if (!url) continue
    const width = typeof candidate.width === 'number' ? candidate.width : 0
    const height = typeof candidate.height === 'number' ? candidate.height : 0
    const area = width && height ? width * height : 0
    if (!best || area > best.area) {
      best = { url, area }
    }
  }

  if (best?.url) return best.url
  const fallback = candidates[candidates.length - 1]
  return fallback?.url || null
}

export function normalizeMediaNode(
  node: Record<string, unknown> | null
): InstagramMediaItem | null {
  if (!node) return null

  const displayUrl =
    (node.display_url as string | undefined) ||
    (node.displayUrl as string | undefined) ||
    pickBestImageUrl(node.display_resources as ImageCandidate[] | undefined) ||
    pickBestImageUrl(
      (node.image_versions2 as { candidates?: ImageCandidate[] } | undefined)?.candidates
    ) ||
    pickBestImageUrl(node.candidates as ImageCandidate[] | undefined) ||
    (node.thumbnail_src as string | undefined) ||
    ''

  if (!displayUrl) return null

  const videoUrl =
    (node.video_url as string | undefined) ||
    (node.videoUrl as string | undefined) ||
    pickBestVideoUrl(node.video_versions as VideoCandidate[] | undefined)

  return {
    displayUrl,
    videoUrl: videoUrl ?? undefined,
    typename: normalizeTypename(node),
  }
}

export function collectMediaItems(
  media: Record<string, unknown> | null
): InstagramMediaItem[] {
  if (!media) return []

  const edges = (
    media.edge_sidecar_to_children as
      | { edges?: Array<{ node?: Record<string, unknown> }> }
      | undefined
  )?.edges

  if (Array.isArray(edges) && edges.length > 0) {
    return edges
      .map((edge) => normalizeMediaNode(edge.node ?? null))
      .filter((item): item is InstagramMediaItem => Boolean(item))
  }

  const carouselMedia = media.carousel_media as Array<Record<string, unknown>> | undefined
  if (Array.isArray(carouselMedia) && carouselMedia.length > 0) {
    return carouselMedia
      .map((item) => normalizeMediaNode(item))
      .filter((item): item is InstagramMediaItem => Boolean(item))
  }

  const childMedia = (media.children as { data?: Array<Record<string, unknown>> } | undefined)
    ?.data
  if (Array.isArray(childMedia) && childMedia.length > 0) {
    return childMedia
      .map((item) => normalizeMediaNode(item))
      .filter((item): item is InstagramMediaItem => Boolean(item))
  }

  const single = normalizeMediaNode(media)
  return single ? [single] : []
}

export function extractCaption(media: Record<string, unknown> | null): string {
  if (!media) return ''

  const edges = (
    media.edge_media_to_caption as { edges?: Array<{ node?: { text?: string } }> } | undefined
  )?.edges
  if (Array.isArray(edges) && edges.length > 0) {
    const text = edges[0]?.node?.text
    if (text) return decodeHtmlEntities(text)
  }

  const caption = media.caption as { text?: string } | string | undefined
  if (typeof caption === 'string') return decodeHtmlEntities(caption)
  if (caption && typeof caption.text === 'string') return decodeHtmlEntities(caption.text)

  return ''
}
