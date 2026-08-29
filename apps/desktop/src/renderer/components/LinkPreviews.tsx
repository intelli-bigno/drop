/// <reference path="../../preload/index.d.ts" />
import { useEffect, useState, useMemo } from 'react'
import { extractYouTubeUrls } from '../lib/youtube-url-utils'
import type { Attachment } from '@drop/shared'
import { Icon } from './Icon'

interface YouTubeOEmbedData {
  title: string
  authorName: string
  authorUrl: string
  thumbnailUrl: string
  videoId: string
  videoUrl: string
}

interface Props {
  content: string
  attachments: Attachment[]
  maxVisible?: number
  onShowMore?: () => void
}

function YouTubeLinkPreview({ url }: { url: string }) {
  const [data, setData] = useState<YouTubeOEmbedData | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(false)

  useEffect(() => {
    let cancelled = false

    const fetchOEmbed = async () => {
      try {
        const result = await window.api.youtube.fetchOEmbed(url)
        if (cancelled) return
        if (result) {
          setData(result)
        } else {
          setError(true)
        }
      } catch {
        if (!cancelled) setError(true)
      } finally {
        if (!cancelled) setLoading(false)
      }
    }

    void fetchOEmbed()
    return () => {
      cancelled = true
    }
  }, [url])

  const openUrl = (target: string) => {
    window.api.openExternal(target)
  }

  if (loading) {
    return (
      <div className="link-preview link-preview-youtube link-preview-loading">
        <div className="link-preview-thumbnail">
          <div className="attachment-skeleton" />
        </div>
        <div className="link-preview-info">
          <div className="link-preview-header">
            <span className="link-preview-icon" aria-hidden="true">
              <Icon name="youtube" size={14} />
            </span>
            <span className="link-preview-label">YouTube</span>
          </div>
          <span className="attachment-skeleton-text" />
        </div>
      </div>
    )
  }

  if (error || !data) {
    return null
  }

  const thumbnailUrl = data.thumbnailUrl || `https://i.ytimg.com/vi/${data.videoId}/hqdefault.jpg`

  return (
    <div
      className="link-preview link-preview-youtube"
      onClick={() => openUrl(data.videoUrl)}
    >
      <div className="link-preview-thumbnail">
        <img src={thumbnailUrl} alt={data.title} />
        <div className="link-preview-play">
          <Icon name="play" size={48} fill="#fff" stroke="none" />
        </div>
      </div>
      <div className="link-preview-info">
        <div className="link-preview-header">
          <span className="link-preview-icon" aria-hidden="true">
            <Icon name="youtube" size={14} />
          </span>
          <span className="link-preview-label">YouTube</span>
        </div>
        {data.title && <p className="link-preview-title">{data.title}</p>}
        {data.authorName && (
          <span
            className="link-preview-author"
            onClick={(e) => {
              e.stopPropagation()
              if (data.authorUrl) openUrl(data.authorUrl)
            }}
          >
            {data.authorName}
          </span>
        )}
      </div>
    </div>
  )
}

export function LinkPreviews({ content, attachments, maxVisible, onShowMore }: Props) {
  // 본문에서 YouTube URL 추출
  const youtubeUrls = useMemo(() => extractYouTubeUrls(content), [content])

  // 이미 attachment로 존재하는 URL 제외
  const existingUrls = useMemo(() => {
    const urls = new Set<string>()
    for (const att of attachments) {
      if (att.originalUrl) {
        urls.add(att.originalUrl)
      }
      // metadata에서 videoUrl도 체크
      const videoUrl = att.metadata?.videoUrl as string | undefined
      if (videoUrl) {
        urls.add(videoUrl)
      }
    }
    return urls
  }, [attachments])

  const newYoutubeUrls = useMemo(
    () => youtubeUrls.filter((url) => !existingUrls.has(url)),
    [youtubeUrls, existingUrls]
  )

  if (newYoutubeUrls.length === 0) {
    return null
  }

  const visibleUrls = maxVisible ? newYoutubeUrls.slice(0, maxVisible) : newYoutubeUrls
  const hiddenCount = maxVisible ? Math.max(0, newYoutubeUrls.length - maxVisible) : 0

  return (
    <div className="link-previews">
      {visibleUrls.map((url) => (
        <YouTubeLinkPreview key={url} url={url} />
      ))}
      {hiddenCount > 0 && onShowMore && (
        <button className="link-preview-more-btn" onClick={onShowMore}>
          +{hiddenCount}개 더보기
        </button>
      )}
    </div>
  )
}
