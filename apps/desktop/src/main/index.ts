import {
  app,
  BrowserWindow,
  dialog,
  globalShortcut,
  ipcMain,
  Menu,
  net,
  nativeImage,
  session,
  shell,
  Tray,
  type ClientRequestConstructorOptions,
} from 'electron'
import { initAutoUpdater, setupUpdaterIpc } from './updater'
import { isQuitting, markQuitting, shouldHideOnClose } from './quit-state'
import { isSafeExternalUrl } from './url-utils'
import {
  type AppSettings,
  DEFAULT_SETTINGS,
  loadSettings,
  saveSettings,
  withQuickCaptureShortcut,
} from './settings'
import {
  registerQuickCaptureShortcut,
  type ShortcutRegistrationResult,
} from './quick-capture-shortcut'
import {
  DEFAULT_QUICK_CAPTURE_ACCELERATOR,
  DEV_QUICK_CAPTURE_ACCELERATOR,
  describeRegistrationFailure,
  normalizeAccelerator,
  resolveQuickCaptureAccelerator,
  shouldReturnFocusToPreviousApp,
} from '../shared/shortcuts'

// Handle EPIPE errors that occur when stdout is closed (e.g., tray app without terminal)
process.on('uncaughtException', (error) => {
  if ((error as NodeJS.ErrnoException).code === 'EPIPE') {
    return // Silently ignore broken pipe errors
  }
  // Re-throw other errors to maintain default behavior
  console.error('[main] Uncaught exception:', error)
})

process.on('unhandledRejection', (reason, promise) => {
  console.error('[main] Unhandled rejection at:', promise, 'reason:', reason)
})
import { join } from 'path'
import {
  type InstagramMediaItem,
  type InstagramPostData,
  parseInstagramUrl,
  decodeInstagramShortcode,
  decodeHtmlEntities,
  extractMetaContent,
  extractMetaName,
  extractJsonLdPayloads,
  extractCaptionFromJsonLd,
  extractAuthorFromJsonLd,
  extractHandleFromText,
  cleanInstagramCaption,
  extractJsonAfterMarker,
  extractJsonFromScript,
  findShortcodeMedia,
  normalizeTypename,
  collectMediaItems,
  extractCaption,
} from './instagram-utils'
const USER_AGENT =
  'Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:120.0) Gecko/20100101 Firefox/120.0'
const INSTAGRAM_USER_AGENT = USER_AGENT
const INSTAGRAM_APP_USER_AGENT = 'Instagram 289.0.0.0.0 Android'
const MAX_REDIRECTS = 5
const MAX_MEDIA_BASE64 = 10
const MAX_VIDEO_BASE64 = 2
const MAX_VIDEO_BYTES = 20 * 1024 * 1024
const INSTAGRAM_SESSION_PARTITION = 'persist:instagram'

export interface YouTubeOEmbedData {
  title: string
  authorName: string
  authorUrl: string
  thumbnailUrl: string
  thumbnailWidth: number
  thumbnailHeight: number
  html: string
  videoId: string
  videoUrl: string
}
const INSTAGRAM_LOGIN_URL = 'https://www.instagram.com/accounts/login/'
const INSTAGRAM_LOGIN_ALLOWED_DOMAINS = ['instagram.com', 'cdninstagram.com', 'facebook.com']

function isAllowedInstagramLoginUrl(url: string): boolean {
  let parsed: URL
  try {
    parsed = new URL(url)
  } catch {
    return false
  }

  if (parsed.protocol !== 'https:') return false

  return INSTAGRAM_LOGIN_ALLOWED_DOMAINS.some(
    (domain) => parsed.hostname === domain || parsed.hostname.endsWith(`.${domain}`)
  )
}

type NetRequestOptions = Pick<
  ClientRequestConstructorOptions,
  'headers' | 'origin' | 'referrerPolicy' | 'session' | 'useSessionCookies'
>

let instagramLoginPromise: Promise<boolean> | null = null

function getInstagramSession() {
  return session.fromPartition(INSTAGRAM_SESSION_PARTITION)
}

async function isInstagramLoggedIn(): Promise<boolean> {
  const instagramSession = getInstagramSession()
  const cookies = await instagramSession.cookies.get({
    url: 'https://www.instagram.com',
    name: 'sessionid',
  })
  return cookies.some((cookie) => Boolean(cookie.value))
}

async function ensureInstagramLogin(): Promise<boolean> {
  if (instagramLoginPromise) return instagramLoginPromise
  if (await isInstagramLoggedIn()) return true

  console.info('[instagram] ensureLogin: opening login window')
  instagramLoginPromise = new Promise((resolve) => {
    const instagramSession = getInstagramSession()
    const loginWindow = new BrowserWindow({
      width: 480,
      height: 720,
      title: 'Instagram Login',
      webPreferences: {
        session: instagramSession,
        nodeIntegration: false,
        contextIsolation: true,
      },
    })

    loginWindow.webContents.setWindowOpenHandler(({ url }) => {
      openExternalSafely(url)
      return { action: 'deny' }
    })

    loginWindow.webContents.on('will-navigate', (event, url) => {
      if (!isAllowedInstagramLoginUrl(url)) {
        event.preventDefault()
      }
    })

    let resolved = false
    const finish = (result: boolean) => {
      if (resolved) return
      resolved = true
      instagramLoginPromise = null
      clearInterval(interval)
      clearTimeout(timeout)
      console.info('[instagram] ensureLogin: finished', { result })
      if (!loginWindow.isDestroyed()) {
        loginWindow.close()
      }
      resolve(result)
    }

    const checkLoggedIn = async () => {
      if (await isInstagramLoggedIn()) {
        finish(true)
      }
    }

    const interval = setInterval(() => {
      void checkLoggedIn()
    }, 1000)

    const timeout = setTimeout(() => {
      console.warn('[instagram] ensureLogin: timeout')
      finish(false)
    }, 2 * 60 * 1000)

    loginWindow.on('closed', () => {
      console.warn('[instagram] ensureLogin: window closed')
      finish(false)
    })

    loginWindow.webContents.on('did-navigate', () => {
      void checkLoggedIn()
    })

    loginWindow.webContents.on('did-navigate-in-page', () => {
      void checkLoggedIn()
    })

    void loginWindow.loadURL(INSTAGRAM_LOGIN_URL)
  })

  return instagramLoginPromise
}

function extractPostDataFromHtml(
  html: string,
  parsed: { shortcode: string; postUrl: string },
  extraPayloads: unknown[] = []
): InstagramPostData | null {
  const metaImageRaw =
    extractMetaContent(html, 'og:image:secure_url') ??
    extractMetaContent(html, 'og:image') ??
    extractMetaContent(html, 'twitter:image') ??
    extractMetaName(html, 'twitter:image')
  const metaTitleRaw =
    extractMetaContent(html, 'og:title') ??
    extractMetaContent(html, 'twitter:title') ??
    extractMetaName(html, 'twitter:title') ??
    ''
  const metaDescRaw =
    extractMetaContent(html, 'og:description') ??
    extractMetaContent(html, 'twitter:description') ??
    extractMetaName(html, 'twitter:description') ??
    extractMetaName(html, 'description') ??
    ''

  const metaImage = metaImageRaw ? decodeHtmlEntities(metaImageRaw) : ''
  const metaTitle = decodeHtmlEntities(metaTitleRaw)
  const metaDesc = decodeHtmlEntities(metaDescRaw)
  const jsonLdPayloads = extractJsonLdPayloads(html)
  const jsonLdCaption = extractCaptionFromJsonLd(jsonLdPayloads)
  const jsonLdAuthor = extractAuthorFromJsonLd(jsonLdPayloads)

  const usernameMatch = metaTitle.match(/^([^:]+?) on Instagram/)
  const descriptionUsernameMatch = metaDesc.match(/- ([^ ]+) on Instagram/)
  const metaUsername = usernameMatch
    ? usernameMatch[1].trim()
    : descriptionUsernameMatch
    ? descriptionUsernameMatch[1].trim()
    : ''

  const payloads = [
    ...extraPayloads,
    extractJsonAfterMarker(html, 'window._sharedData'),
    extractJsonAfterMarker(html, '__additionalDataLoaded'),
    extractJsonFromScript(html, '__NEXT_DATA__'),
  ].filter(Boolean)

  for (const payload of payloads) {
    const mediaNode = findShortcodeMedia(payload)
    if (!mediaNode || typeof mediaNode !== 'object') continue

    const mediaRecord = mediaNode as Record<string, unknown>
    console.info('[instagram] mediaRecord keys:', Object.keys(mediaRecord))
    console.info('[instagram] edge_sidecar_to_children:', mediaRecord.edge_sidecar_to_children)
    console.info('[instagram] carousel_media:', mediaRecord.carousel_media)
    console.info('[instagram] children:', mediaRecord.children)
    console.info('[instagram] __typename:', mediaRecord.__typename)
    console.info('[instagram] media_type:', mediaRecord.media_type)
    const mediaItems = collectMediaItems(mediaRecord)
    console.info('[instagram] collected mediaItems:', mediaItems.length, mediaItems)
    const captionCandidate = extractCaption(mediaRecord) || jsonLdCaption || metaDesc || metaTitle
    const caption = cleanInstagramCaption(captionCandidate)

    const displayName = jsonLdAuthor || metaUsername
    const username =
      (mediaRecord.owner as { username?: string } | undefined)?.username ||
      (mediaRecord.user as { username?: string } | undefined)?.username ||
      extractHandleFromText(jsonLdAuthor) ||
      extractHandleFromText(metaDesc) ||
      extractHandleFromText(metaTitle) ||
      displayName

    const profilePicUrl =
      (mediaRecord.owner as { profile_pic_url?: string } | undefined)?.profile_pic_url ||
      (mediaRecord.user as { profile_pic_url?: string } | undefined)?.profile_pic_url ||
      ''

    const timestamp =
      (mediaRecord.taken_at_timestamp as number | undefined) ??
      (mediaRecord.taken_at as number | undefined) ??
      0

    const typename = normalizeTypename(mediaRecord)
    const primary = mediaItems[0]
    const displayUrl = primary?.displayUrl || metaImage
    const videoUrl = primary?.videoUrl
    const media =
      mediaItems.length > 0
        ? mediaItems
        : displayUrl
        ? [{ displayUrl, videoUrl, typename }]
        : []

    return {
      shortcode: (mediaRecord.shortcode as string | undefined) || parsed.shortcode,
      displayUrl,
      videoUrl,
      caption,
      username,
      displayName,
      profilePicUrl,
      timestamp,
      typename,
      media,
    }
  }

  if (!metaImage && !metaTitle && !metaDesc) {
    console.warn('[instagram] no JSON payload and no HTML meta tags found')
    return null
  }

  console.warn('[instagram] falling back to HTML meta tags (only first image will be available)')
  const captionCandidate = jsonLdCaption || metaDesc || metaTitle
  const caption = cleanInstagramCaption(captionCandidate)
  const displayName = jsonLdAuthor || metaUsername
  const media = metaImage ? [{ displayUrl: metaImage, typename: 'GraphImage' }] : []

  return {
    shortcode: parsed.shortcode,
    displayUrl: metaImage,
    videoUrl: undefined,
    caption,
    username:
      extractHandleFromText(jsonLdAuthor) ||
      extractHandleFromText(metaDesc) ||
      extractHandleFromText(metaTitle) ||
      displayName,
    displayName,
    profilePicUrl: '',
    timestamp: 0,
    typename: 'GraphImage',
    media,
  }
}

function getHeaderValue(
  headers: Record<string, string | string[] | undefined>,
  name: string
): string | undefined {
  const value = headers[name.toLowerCase()]
  if (Array.isArray(value)) return value[0]
  return value
}

async function fetchBufferWithRedirect(
  url: string,
  options: NetRequestOptions,
  redirectCount = 0,
  maxBytes?: number
): Promise<{ buffer: Buffer; headers: Record<string, string | string[] | undefined> } | null> {
  return new Promise((resolve) => {
    const request = net.request({ url, ...options })
    let settled = false

    const finish = (
      value: { buffer: Buffer; headers: Record<string, string | string[] | undefined> } | null
    ) => {
      if (settled) return
      settled = true
      resolve(value)
    }

    const chunks: Buffer[] = []

    request.on('response', (response) => {
      const statusCode = response.statusCode ?? 0
      const location = getHeaderValue(response.headers, 'location')

      if (
        statusCode >= 300 &&
        statusCode < 400 &&
        location &&
        redirectCount < MAX_REDIRECTS
      ) {
        const nextUrl = new URL(location, url).toString()
        void fetchBufferWithRedirect(nextUrl, options, redirectCount + 1, maxBytes).then(finish)
        return
      }

      if (statusCode < 200 || statusCode >= 300) {
        console.error('Instagram request error:', { statusCode, url })
        finish(null)
        return
      }

      if (maxBytes) {
        const contentLength = getHeaderValue(response.headers, 'content-length')
        if (contentLength && Number(contentLength) > maxBytes) {
          console.warn('[instagram] media too large (content-length)', {
            url,
            maxBytes,
            contentLength,
          })
          // Drain the response to avoid memory leaks
          response.on('data', () => {})
          finish(null)
          return
        }
      }

      let totalBytes = 0
      response.on('data', (chunk) => {
        if (settled) return
        const bufferChunk = Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk)
        totalBytes += bufferChunk.length
        if (maxBytes && totalBytes > maxBytes) {
          console.warn('[instagram] media too large (stream)', {
            url,
            maxBytes,
            totalBytes,
          })
          request.abort()
          finish(null)
          return
        }
        chunks.push(bufferChunk)
      })

      response.on('end', () => {
        finish({ buffer: Buffer.concat(chunks), headers: response.headers })
      })
    })

    request.on('error', (e) => {
      if (settled) return
      console.error('Instagram request error:', e)
      finish(null)
    })

    request.end()
  })
}

async function fetchHtml(url: string): Promise<string | null> {
  const instagramSession = getInstagramSession()
  const result = await fetchBufferWithRedirect(url, {
    headers: {
      'User-Agent': INSTAGRAM_USER_AGENT,
      Accept: 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      'Accept-Language': 'en-US,en;q=0.5',
      'Accept-Encoding': 'identity',
    },
    session: instagramSession,
    useSessionCookies: true,
  })

  if (!result) return null
  return result.buffer.toString('utf8')
}

async function getInstagramCsrfToken(): Promise<string | undefined> {
  const instagramSession = getInstagramSession()
  const cookies = await instagramSession.cookies.get({
    url: 'https://www.instagram.com',
    name: 'csrftoken',
  })
  return cookies[0]?.value
}

function buildInstagramJsonUrl(postUrl: string): string {
  const url = new URL(postUrl)
  url.searchParams.set('__a', '1')
  url.searchParams.set('__d', 'dis')
  return url.toString()
}

function buildInstagramApiUrls(shortcode: string): string[] {
  const mediaId = decodeInstagramShortcode(shortcode)
  const urls: string[] = []
  if (mediaId) {
    urls.push(`https://i.instagram.com/api/v1/media/${mediaId}/info/`)
    urls.push(`https://www.instagram.com/api/v1/media/${mediaId}/info/`)
  }
  urls.push(`https://i.instagram.com/api/v1/media/shortcode/${shortcode}/`)
  urls.push(`https://www.instagram.com/api/v1/media/shortcode/${shortcode}/`)
  return urls
}

async function fetchJson(
  url: string,
  refererUrl?: string,
  userAgentOverride?: string
): Promise<unknown | null> {
  const instagramSession = getInstagramSession()
  const csrfToken = await getInstagramCsrfToken()
  const origin = refererUrl ? new URL(refererUrl).origin : 'https://www.instagram.com'
  const result = await fetchBufferWithRedirect(url, {
    headers: {
      'User-Agent': userAgentOverride ?? INSTAGRAM_USER_AGENT,
      Accept: 'application/json,text/plain,*/*',
      'Accept-Language': 'en-US,en;q=0.5',
      'Accept-Encoding': 'identity',
      'X-IG-App-ID': '936619743392459',
      'X-ASBD-ID': '129477',
      'X-Requested-With': 'XMLHttpRequest',
      ...(csrfToken ? { 'X-CSRFToken': csrfToken } : {}),
      ...(refererUrl ? { Referer: refererUrl } : {}),
    },
    session: instagramSession,
    useSessionCookies: true,
    origin,
  })

  if (!result) return null
  const text = result.buffer.toString('utf8').trim()
  if (!text) return null

  const sanitized = text.startsWith('for (;;);') ? text.slice(9) : text
  try {
    return JSON.parse(sanitized)
  } catch (error) {
    console.warn('[instagram] json parse failed', error)
    return null
  }
}

async function fetchInstagramJsonPayload(parsed: {
  shortcode: string
  postUrl: string
}): Promise<unknown[]> {
  const urls = [buildInstagramJsonUrl(parsed.postUrl), ...buildInstagramApiUrls(parsed.shortcode)]
  console.info('[instagram] trying JSON endpoints:', urls)
  for (const url of urls) {
    const useAppUa = url.includes('/api/v1/')
    console.info('[instagram] fetching:', url)
    const payload = await fetchJson(
      url,
      parsed.postUrl,
      useAppUa ? INSTAGRAM_APP_USER_AGENT : undefined
    )
    if (!payload) {
      console.info('[instagram] no payload from:', url)
      continue
    }
    console.info('[instagram] payload received, keys:', Object.keys(payload as Record<string, unknown>))
    const found = findShortcodeMedia(payload)
    if (found) {
      console.info('[instagram] found shortcode_media in payload')
      return [payload]
    }
    console.info('[instagram] no shortcode_media found in payload')
  }
  console.warn('[instagram] no valid JSON payload found from any endpoint')
  return []
}

async function fetchImageAsBase64(imageUrl: string, refererUrl?: string): Promise<string | null> {
  if (!imageUrl) return null

  const instagramSession = getInstagramSession()
  const headers: Record<string, string> = {
    'User-Agent': INSTAGRAM_USER_AGENT,
    Accept: 'image/avif,image/webp,image/apng,image/*,*/*;q=0.8',
    'Accept-Language': 'en-US,en;q=0.5',
    'Accept-Encoding': 'identity',
  }

  const origin = refererUrl ? new URL(refererUrl).origin : undefined
  const result = await fetchBufferWithRedirect(imageUrl, {
    headers,
    session: instagramSession,
    useSessionCookies: true,
    origin,
    referrerPolicy: 'no-referrer',
  })
  if (!result) return null

  const contentType = getHeaderValue(result.headers, 'content-type')
  const mimeType = contentType || 'image/jpeg'
  const base64 = result.buffer.toString('base64')
  return `data:${mimeType};base64,${base64}`
}

async function fetchVideoAsBase64(videoUrl: string, refererUrl?: string): Promise<string | null> {
  if (!videoUrl) return null

  const instagramSession = getInstagramSession()
  const headers: Record<string, string> = {
    'User-Agent': INSTAGRAM_USER_AGENT,
    Accept: 'video/*,*/*;q=0.8',
    'Accept-Language': 'en-US,en;q=0.5',
    'Accept-Encoding': 'identity',
  }

  const origin = refererUrl ? new URL(refererUrl).origin : undefined
  const result = await fetchBufferWithRedirect(
    videoUrl,
    {
      headers,
      session: instagramSession,
      useSessionCookies: true,
      origin,
      referrerPolicy: 'no-referrer',
    },
    0,
    MAX_VIDEO_BYTES
  )

  if (!result) return null

  const contentType = getHeaderValue(result.headers, 'content-type')
  const mimeType = contentType || 'video/mp4'
  const base64 = result.buffer.toString('base64')
  return `data:${mimeType};base64,${base64}`
}
async function fetchInstagramPost(postUrl: string): Promise<InstagramPostData | null> {
  const parsed = parseInstagramUrl(postUrl)
  if (!parsed) return null

  const [html, jsonPayloads] = await Promise.all([
    fetchHtml(parsed.postUrl),
    fetchInstagramJsonPayload(parsed),
  ])

  if (!html && jsonPayloads.length === 0) return null

  const extraPayloads = jsonPayloads
  const htmlSource = html ?? ''
  return extractPostDataFromHtml(htmlSource, parsed, extraPayloads)
}

// YouTube oEmbed 캐시 (videoId -> data, 15분 TTL)
const youtubeOEmbedCache = new Map<string, { data: YouTubeOEmbedData; timestamp: number }>()
const youtubeOEmbedPending = new Map<string, Promise<YouTubeOEmbedData | null>>()
const YOUTUBE_CACHE_TTL = 15 * 60 * 1000 // 15 minutes

function extractYouTubeVideoId(url: string): string | null {
  try {
    const parsed = new URL(url)
    const hostname = parsed.hostname.replace(/^www\./, '').replace(/^m\./, '')

    if (hostname === 'youtu.be') {
      const videoId = parsed.pathname.slice(1).split('/')[0]
      if (videoId && /^[A-Za-z0-9_-]{11}$/.test(videoId)) {
        return videoId
      }
      return null
    }

    if (!hostname.includes('youtube')) return null

    if (parsed.pathname === '/watch') {
      const videoId = parsed.searchParams.get('v')
      if (videoId && /^[A-Za-z0-9_-]{11}$/.test(videoId)) {
        return videoId
      }
      return null
    }

    const pathMatch = parsed.pathname.match(/^\/(?:embed|v|shorts|live)\/([A-Za-z0-9_-]{11})/)
    if (pathMatch) {
      return pathMatch[1]
    }

    return null
  } catch {
    return null
  }
}

async function fetchYouTubeOEmbed(videoUrl: string): Promise<YouTubeOEmbedData | null> {
  const videoId = extractYouTubeVideoId(videoUrl)
  if (!videoId) {
    console.warn('[youtube] invalid video URL:', videoUrl)
    return null
  }

  // 캐시 확인
  const cached = youtubeOEmbedCache.get(videoId)
  if (cached && Date.now() - cached.timestamp < YOUTUBE_CACHE_TTL) {
    console.info('[youtube] fetchOEmbed: cache hit', { videoId })
    return cached.data
  }

  // 진행 중인 요청이 있으면 대기
  const pending = youtubeOEmbedPending.get(videoId)
  if (pending) {
    console.info('[youtube] fetchOEmbed: waiting for pending request', { videoId })
    return pending
  }

  const canonicalUrl = `https://www.youtube.com/watch?v=${videoId}`
  const oembedUrl = `https://www.youtube.com/oembed?url=${encodeURIComponent(canonicalUrl)}&format=json`

  console.info('[youtube] fetching oEmbed:', oembedUrl)

  // 요청을 Promise로 래핑하여 pending에 등록
  const fetchPromise = (async (): Promise<YouTubeOEmbedData | null> => {
    const result = await fetchBufferWithRedirect(oembedUrl, {
      headers: {
        'User-Agent': USER_AGENT,
        Accept: 'application/json',
      },
    })

    if (!result) {
      console.warn('[youtube] oEmbed fetch failed')
      return null
    }

    try {
      const text = result.buffer.toString('utf8')
      const data = JSON.parse(text) as {
        title?: string
        author_name?: string
        author_url?: string
        thumbnail_url?: string
        thumbnail_width?: number
        thumbnail_height?: number
        html?: string
      }

      // Use maxresdefault thumbnail if available
      let thumbnailUrl = data.thumbnail_url || ''
      if (thumbnailUrl) {
        // Try to get higher quality thumbnail
        thumbnailUrl = `https://i.ytimg.com/vi/${videoId}/maxresdefault.jpg`
      }

      const oembedData: YouTubeOEmbedData = {
        title: data.title || '',
        authorName: data.author_name || '',
        authorUrl: data.author_url || '',
        thumbnailUrl,
        thumbnailWidth: data.thumbnail_width || 0,
        thumbnailHeight: data.thumbnail_height || 0,
        html: data.html || '',
        videoId,
        videoUrl: canonicalUrl,
      }

      // 캐시에 저장
      youtubeOEmbedCache.set(videoId, { data: oembedData, timestamp: Date.now() })

      return oembedData
    } catch (error) {
      console.error('[youtube] oEmbed parse error:', error)
      return null
    }
  })()

  // pending에 등록하고 완료 시 제거
  youtubeOEmbedPending.set(videoId, fetchPromise)
  try {
    return await fetchPromise
  } finally {
    youtubeOEmbedPending.delete(videoId)
  }
}

function setupIpcHandlers(): void {
  ipcMain.handle('shell:openExternal', async (_event, url: string) => {
    if (!isSafeExternalUrl(url)) {
      return { success: false }
    }
    await shell.openExternal(url)
    return { success: true }
  })

  ipcMain.handle('instagram:ensureLogin', async () => ensureInstagramLogin())

  ipcMain.handle('instagram:fetchPost', async (_event, postUrl: string) => {
    console.info('[instagram] fetchPost start', { postUrl })
    const postData = await fetchInstagramPost(postUrl)
    if (!postData) {
      console.warn('[instagram] fetchPost: no data')
      return null
    }

    const baseMedia =
      postData.media.length > 0
        ? postData.media
        : postData.displayUrl
        ? [
            {
              displayUrl: postData.displayUrl,
              videoUrl: postData.videoUrl,
              typename: postData.typename,
            },
          ]
        : []

    const media: InstagramMediaItem[] = []
    let imageCount = 0
    let videoCount = 0

    for (const item of baseMedia) {
      let imageBase64: string | null = null
      let videoBase64: string | null = null

      if (item.displayUrl && imageCount < MAX_MEDIA_BASE64) {
        imageBase64 = await fetchImageAsBase64(item.displayUrl, postUrl)
        if (imageBase64) {
          imageCount += 1
        }
      }

      if (item.videoUrl && videoCount < MAX_VIDEO_BASE64) {
        videoBase64 = await fetchVideoAsBase64(item.videoUrl, postUrl)
        if (videoBase64) {
          videoCount += 1
        }
      }

      media.push({
        ...item,
        imageBase64,
        videoBase64,
      })
    }

    console.info('[instagram] fetchPost: done', {
      mediaCount: media.length,
      hasCaption: Boolean(postData.caption),
    })
    return {
      ...postData,
      media,
    }
  })

  ipcMain.handle('youtube:fetchOEmbed', async (_event, videoUrl: string) => {
    console.info('[youtube] fetchOEmbed start', { videoUrl })
    const oembedData = await fetchYouTubeOEmbed(videoUrl)
    if (!oembedData) {
      console.warn('[youtube] fetchOEmbed: no data')
      return null
    }

    console.info('[youtube] fetchOEmbed: done', {
      title: oembedData.title,
      authorName: oembedData.authorName,
    })

    return oembedData
  })
}

let tray: Tray | null = null
let mainWindow: BrowserWindow | null = null
let quickCaptureWindow: BrowserWindow | null = null

let appSettings: AppSettings = { ...DEFAULT_SETTINGS }
/** 지금 실제로 등록돼 있는 전역 조합. 등록에 모두 실패하면 null. */
let activeQuickCaptureAccelerator: string | null = null
/** 이번 캡처가 다른 앱에서 불려 왔는가 — 닫을 때 포커스를 돌려줄지 판단한다. */
let quickCaptureInvokedFromOtherApp = false

function getRendererUrl(hash = ''): string {
  if (process.env.ELECTRON_RENDERER_URL) {
    return `${process.env.ELECTRON_RENDERER_URL}${hash ? `#${hash}` : ''}`
  }
  return `file://${join(__dirname, '../renderer/index.html')}${hash ? `#${hash}` : ''}`
}

function openExternalSafely(url: string): void {
  if (isSafeExternalUrl(url)) {
    void shell.openExternal(url)
  }
}

function isAppOriginUrl(url: string): boolean {
  let parsed: URL
  try {
    parsed = new URL(url)
  } catch {
    return false
  }

  if (parsed.protocol === 'file:') return true

  const rendererUrl = process.env.ELECTRON_RENDERER_URL
  if (rendererUrl) {
    try {
      return parsed.origin === new URL(rendererUrl).origin
    } catch {
      return false
    }
  }

  return false
}

// 앱 자체 창(main, quick capture) 보안 강화:
// window.open은 모두 차단(http/https는 외부 브라우저로), 앱 origin 밖으로의 navigation 금지
function hardenAppWindow(window: BrowserWindow): void {
  window.webContents.setWindowOpenHandler(({ url }) => {
    openExternalSafely(url)
    return { action: 'deny' }
  })

  window.webContents.on('will-navigate', (event, url) => {
    if (!isAppOriginUrl(url)) {
      event.preventDefault()
      openExternalSafely(url)
    }
  })
}

/** 지금 이 앱의 창 중 하나가 포커스를 쥐고 있는가. */
function isAppFocused(): boolean {
  return BrowserWindow.getAllWindows().some((window) => !window.isDestroyed() && window.isFocused())
}

function createQuickCaptureWindow(options: { fromGlobalShortcut?: boolean } = {}): void {
  // 전역 단축키로 들어온 경우에만, 그리고 앱이 포커스가 아니었을 때만 포커스를 되돌려준다.
  quickCaptureInvokedFromOtherApp = Boolean(options.fromGlobalShortcut) && !isAppFocused()

  if (quickCaptureWindow && !quickCaptureWindow.isDestroyed()) {
    // 이미 창이 있으면 포커스
    app.focus({ steal: true })
    quickCaptureWindow.show()
    quickCaptureWindow.focus()
    quickCaptureWindow.webContents.focus()
    return
  }

  quickCaptureWindow = new BrowserWindow({
    width: 600,
    height: 80,
    frame: false,
    transparent: true,
    alwaysOnTop: true,
    skipTaskbar: true,
    center: true,
    show: false,
    resizable: false,
    movable: true,
    hasShadow: true,
    vibrancy: 'under-window',
    visualEffectState: 'active',
    webPreferences: {
      preload: join(__dirname, '../preload/index.js'),
      contextIsolation: true,
      nodeIntegration: false,
    },
  })

  hardenAppWindow(quickCaptureWindow)

  quickCaptureWindow.loadURL(getRendererUrl('quick-capture'))

  quickCaptureWindow.once('ready-to-show', () => {
    if (!quickCaptureWindow) return
    // macOS에서 다른 앱에서 호출될 때 포커스 강제
    app.focus({ steal: true })
    quickCaptureWindow.show()
    quickCaptureWindow.focus()
    // webContents에도 포커스 (입력창 포커스)
    quickCaptureWindow.webContents.focus()
  })

  quickCaptureWindow.on('blur', () => {
    // 포커스 잃으면 숨김. 이미 포커스가 다른 곳으로 갔으므로 app.hide()는 하지 않는다.
    if (quickCaptureWindow && !quickCaptureWindow.isDestroyed()) {
      quickCaptureWindow.hide()
    }
    quickCaptureInvokedFromOtherApp = false
  })

  quickCaptureWindow.on('closed', () => {
    quickCaptureWindow = null
  })
}

function hideQuickCaptureWindow(): void {
  if (quickCaptureWindow && !quickCaptureWindow.isDestroyed()) {
    quickCaptureWindow.hide()
  }

  // 다른 앱에서 불러온 캡처였다면 그 앱으로 포커스를 돌려준다 (BRU-84).
  // macOS는 앱 단위 hide가 직전 앱을 다시 앞으로 올려 준다.
  if (
    shouldReturnFocusToPreviousApp({
      platform: process.platform,
      invokedFromOtherApp: quickCaptureInvokedFromOtherApp,
    })
  ) {
    app.hide()
  }

  quickCaptureInvokedFromOtherApp = false
}

function showMainWindow(): void {
  // macOS: 독 아이콘 복원
  if (process.platform === 'darwin') {
    app.dock?.show()
  }

  if (mainWindow && !mainWindow.isDestroyed()) {
    mainWindow.show()
    mainWindow.focus()
  } else {
    createWindow()
  }
}

function createTray(): void {
  // 템플릿 이미지 생성 (macOS 메뉴바 스타일)
  const iconPath = join(__dirname, '../../build/trayIconTemplate.png')
  let icon: Electron.NativeImage

  try {
    icon = nativeImage.createFromPath(iconPath)
    if (icon.isEmpty()) {
      // 아이콘 파일이 없으면 기본 아이콘 생성
      icon = nativeImage.createEmpty()
    }
  } catch {
    icon = nativeImage.createEmpty()
  }

  // 16x16 템플릿 이미지로 리사이즈
  if (!icon.isEmpty()) {
    icon = icon.resize({ width: 16, height: 16 })
    icon.setTemplateImage(true)
  }

  tray = new Tray(icon)
  tray.setToolTip('Braindump')

  refreshTrayMenu()

  tray.on('click', () => {
    showMainWindow()
  })
}

/** 등록된 조합이 바뀌면 메뉴 라벨도 따라가야 한다 — 안 맞는 라벨은 거짓말이 된다. */
function refreshTrayMenu(): void {
  if (!tray || tray.isDestroyed()) return

  const contextMenu = Menu.buildFromTemplate([
    {
      label: 'Quick Capture',
      // 등록에 실패했으면 조합을 표시하지 않는다 — 눌러도 안 되는 키를 적어 두지 않는다.
      accelerator: activeQuickCaptureAccelerator ?? undefined,
      click: () => createQuickCaptureWindow(),
    },
    {
      label: 'Open Braindump',
      click: () => showMainWindow(),
    },
    { type: 'separator' },
    {
      label: 'Quit',
      click: () => {
        app.quit()
      },
    },
  ])

  tray.setContextMenu(contextMenu)
}

/**
 * 퀵캡처 전역 단축키를 등록한다 (BRU-84).
 *
 * 실제 등록 판단은 `registerQuickCaptureShortcut`에 있다 — 여기서는 Electron 객체를 넘기고
 * 결과를 앱 상태(활성 조합·트레이 메뉴)에 반영하는 일만 한다.
 */
function applyQuickCaptureShortcut(): ShortcutRegistrationResult {
  const preferred = resolveQuickCaptureAccelerator({
    stored: appSettings.quickCaptureShortcut,
    isPackaged: app.isPackaged,
  })
  const fallback = app.isPackaged ? DEFAULT_QUICK_CAPTURE_ACCELERATOR : DEV_QUICK_CAPTURE_ACCELERATOR

  const result = registerQuickCaptureShortcut({
    registrar: globalShortcut,
    preferred,
    fallback,
    previous: activeQuickCaptureAccelerator,
    onTrigger: () => {
      createQuickCaptureWindow({ fromGlobalShortcut: true })
    },
    onError: (accelerator, error) => {
      console.warn(`[globalShortcut] ${accelerator} 등록 중 오류:`, error)
    },
  })

  activeQuickCaptureAccelerator = result.accelerator
  if (result.accelerator) {
    console.info(`[globalShortcut] 퀵캡처 전역 단축키 등록: ${result.accelerator}`)
  } else {
    console.warn(
      `[globalShortcut] 등록 실패 — 다른 앱이 점유 중일 수 있습니다: ${result.attempted.join(', ')}`
    )
  }
  refreshTrayMenu()

  return result
}

/** 등록 실패를 사용자에게 보여 준다 — 로그만 남기고 넘어가지 않는다. */
function notifyShortcutRegistrationFailure(attempted: string[]): void {
  const { title, message } = describeRegistrationFailure(attempted, process.platform)
  void dialog.showMessageBox({ type: 'warning', title, message, buttons: ['확인'] })
}

function createWindow(): void {
  mainWindow = new BrowserWindow({
    width: 1200,
    height: 800,
    webPreferences: {
      preload: join(__dirname, '../preload/index.js'),
      contextIsolation: true,
      nodeIntegration: false,
    },
    titleBarStyle: 'hiddenInset',
    trafficLightPosition: { x: 16, y: 16 },
  })

  hardenAppWindow(mainWindow)

  mainWindow.loadURL(getRendererUrl())

  // macOS: Cmd+W로 창을 닫으면 숨기기만 함 (앱은 계속 실행)
  // 단, app.quit() 호출 시에는 실제로 종료
  mainWindow.on('close', (event) => {
    if (shouldHideOnClose(process.platform, isQuitting())) {
      event.preventDefault()
      mainWindow?.hide()
      // 독에서도 숨김 (메뉴바 앱처럼 동작)
      app.dock?.hide()
    }
  })

  mainWindow.on('closed', () => {
    mainWindow = null
  })
}

// Register custom protocol for OAuth callback
if (process.defaultApp) {
  if (process.argv.length >= 2) {
    app.setAsDefaultProtocolClient('drop', process.execPath, [process.argv[1]])
  }
} else {
  app.setAsDefaultProtocolClient('drop')
}

// Handle OAuth callback URL (macOS)
app.on('open-url', (event, url) => {
  event.preventDefault()
  handleOAuthCallback(url)
})

function handleOAuthCallback(url: string): void {
  console.info('[auth] OAuth callback received:', url)

  // Parse the URL to extract tokens
  // URL format: drop://auth/callback#access_token=xxx&refresh_token=xxx&...
  if (url.startsWith('drop://auth/callback')) {
    // Send to renderer process
    if (mainWindow && !mainWindow.isDestroyed()) {
      mainWindow.webContents.send('auth:callback', url)
      mainWindow.show()
      mainWindow.focus()
    }
  }
}

// dev 실행이 설치본과 세션/캐시(userData)를 공유하지 않도록 분리 — whenReady 이전에 설정해야 함
if (!app.isPackaged) {
  app.setPath('userData', `${app.getPath('userData')}-dev`)
}

app.whenReady().then(() => {
  appSettings = loadSettings(app.getPath('userData'))

  setupIpcHandlers()
  setupQuickCaptureHandlers()
  setupSettingsHandlers()
  setupUpdaterIpc()
  createTray()

  const shortcutResult = applyQuickCaptureShortcut()
  if (!shortcutResult.ok) {
    notifyShortcutRegistrationFailure(shortcutResult.attempted)
  }

  createWindow()

  // Initialize auto-updater after window is created
  if (mainWindow) {
    initAutoUpdater(mainWindow)
  }

  // Handle OAuth callback URL (Windows/Linux - second instance)
  const gotTheLock = app.requestSingleInstanceLock()
  if (!gotTheLock) {
    app.quit()
  } else {
    app.on('second-instance', (_event, argv) => {
      // Windows: the URL is in argv
      const url = argv.find((arg) => arg.startsWith('drop://'))
      if (url) {
        handleOAuthCallback(url)
      }
      if (mainWindow) {
        if (mainWindow.isMinimized()) mainWindow.restore()
        mainWindow.focus()
      }
    })
  }

  app.on('activate', () => {
    showMainWindow()
  })
})

// app.quit() 호출 시 종료 상태로 전환 — 이후 창 닫기는 숨기지 않고 실제로 닫힌다
app.on('before-quit', () => {
  markQuitting()
})

// 메뉴바 앱으로 동작: 창을 모두 닫아도 앱 종료하지 않음
app.on('window-all-closed', () => {
  // macOS에서는 Tray로 계속 실행, 다른 OS에서는 종료
  if (process.platform !== 'darwin') {
    app.quit()
  }
})

app.on('will-quit', () => {
  // 앱 종료 시 전역 단축키 해제
  globalShortcut.unregisterAll()
})

function setupQuickCaptureHandlers(): void {
  ipcMain.handle('quickCapture:close', () => {
    hideQuickCaptureWindow()
  })

  ipcMain.handle('quickCapture:submit', async (_event, content: string) => {
    hideQuickCaptureWindow()
    // 메인 윈도우로 노트 생성 요청 전달
    const hasMainWindow = mainWindow !== null && !mainWindow.isDestroyed()
    if (hasMainWindow && mainWindow) {
      mainWindow.webContents.send('quickCapture:noteCreated', content)
    }
    return { success: true, handledByMainWindow: hasMainWindow }
  })

  // 메인 윈도우에서 QuickCapture 열기 요청 처리
  ipcMain.handle('quickCapture:open', () => {
    createQuickCaptureWindow()
  })

  // QuickCapture에서 직접 저장 후 메인 윈도우에 refresh 알림
  ipcMain.handle('quickCapture:notifyRefresh', () => {
    if (mainWindow && !mainWindow.isDestroyed()) {
      mainWindow.webContents.send('quickCapture:refresh')
    }
  })
}

/** 화면이 읽는 단축키 현재 상태. */
interface QuickCaptureShortcutState {
  /** 실제로 등록된 조합. 등록에 실패했으면 null. */
  accelerator: string | null
  /** 사용자가 직접 고른 조합. null이면 기본값을 따르고 있다는 뜻. */
  custom: string | null
  /** 이 빌드의 기본 조합. */
  fallback: string
  /** 등록 성공 여부. */
  registered: boolean
}

function quickCaptureShortcutState(): QuickCaptureShortcutState {
  return {
    accelerator: activeQuickCaptureAccelerator,
    custom: appSettings.quickCaptureShortcut,
    fallback: app.isPackaged ? DEFAULT_QUICK_CAPTURE_ACCELERATOR : DEV_QUICK_CAPTURE_ACCELERATOR,
    registered: activeQuickCaptureAccelerator !== null,
  }
}

function setupSettingsHandlers(): void {
  ipcMain.handle('settings:getQuickCaptureShortcut', () => quickCaptureShortcutState())

  // null을 주면 기본값으로 되돌린다.
  ipcMain.handle('settings:setQuickCaptureShortcut', (_event, accelerator: string | null) => {
    if (accelerator !== null && !normalizeAccelerator(accelerator)) {
      return {
        ok: false,
        error: `쓸 수 없는 조합입니다: ${accelerator}`,
        state: quickCaptureShortcutState(),
      }
    }

    const previous = appSettings
    appSettings = withQuickCaptureShortcut(appSettings, accelerator)

    const result = applyQuickCaptureShortcut()
    if (!result.ok) {
      // 새 조합이 안 잡히면 되돌린다 — 단축키가 없는 상태로 두지 않는다.
      appSettings = previous
      applyQuickCaptureShortcut()
      return {
        ok: false,
        error: describeRegistrationFailure(result.attempted, process.platform).message,
        state: quickCaptureShortcutState(),
      }
    }

    try {
      saveSettings(app.getPath('userData'), appSettings)
    } catch (error) {
      console.warn('[settings] 저장 실패:', error)
      return {
        ok: false,
        error: '단축키는 적용됐지만 저장하지 못했습니다. 다음 실행에는 기본값으로 돌아갑니다.',
        state: quickCaptureShortcutState(),
      }
    }

    return { ok: true, state: quickCaptureShortcutState() }
  })
}
