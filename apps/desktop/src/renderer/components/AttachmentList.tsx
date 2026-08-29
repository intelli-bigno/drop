/// <reference path="../../preload/index.d.ts" />
import { useEffect, useState, useCallback, useMemo } from 'react'
import { FileIcon, defaultStyles } from 'react-file-icon'
import type { Attachment } from '@drop/shared'
import {
  getAttachmentUrl,
  getSignedAttachmentUrl,
  invalidateSignedAttachmentUrl,
} from '../lib/supabase'
import { Icon } from './Icon'

interface Props {
  attachments: Attachment[]
  /** 없으면 첨부를 읽기 전용으로 그린다 (BRU-59) */
  onRemove?: (attachmentId: string) => void
  maxVisible?: number
  onShowMore?: () => void
}

interface ImageGalleryProps {
  images: Attachment[]
  currentIndex: number
  onClose: () => void
  onNavigate: (index: number) => void
}

function formatFileSize(bytes?: number): string {
  if (!bytes) return ''
  if (bytes < 1024) return `${bytes} B`
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`
  return `${(bytes / (1024 * 1024)).toFixed(1)} MB`
}

function getExtension(filename?: string, mimeType?: string): string {
  if (filename) {
    const ext = filename.split('.').pop()?.toLowerCase()
    if (ext) return ext
  }
  if (mimeType) {
    if (mimeType.includes('pdf')) return 'pdf'
    if (mimeType.includes('word')) return 'docx'
    if (mimeType.includes('excel') || mimeType.includes('sheet')) return 'xlsx'
    if (mimeType.includes('powerpoint') || mimeType.includes('presentation')) return 'pptx'
    if (mimeType.startsWith('video/')) return 'mp4'
    if (mimeType.startsWith('audio/')) return 'mp3'
    if (mimeType.includes('zip')) return 'zip'
    if (mimeType.includes('json')) return 'json'
    if (mimeType.startsWith('text/')) return 'txt'
  }
  return 'file'
}

function useAttachmentUrl(storagePath: string) {
  const [url, setUrl] = useState<string | null>(null)
  const [retryCount, setRetryCount] = useState(0)

  useEffect(() => {
    let cancelled = false

    const load = async () => {
      const signed = await getSignedAttachmentUrl(storagePath)
      if (cancelled) return
      if (signed) {
        setUrl(signed)
        return
      }
      setUrl(getAttachmentUrl(storagePath))
    }

    void load()
    return () => {
      cancelled = true
    }
  }, [storagePath, retryCount])

  // 재시도는 캐시를 건너뛴다 — 캐시된 URL 그대로 다시 물으면 같은 실패를 반복한다
  const retry = () => {
    invalidateSignedAttachmentUrl(storagePath)
    setRetryCount((c) => c + 1)
  }

  return { url, retry }
}

function ImageGalleryModal({ images, currentIndex, onClose, onNavigate }: ImageGalleryProps) {
  const currentImage = images[currentIndex]
  const { url } = useAttachmentUrl(currentImage?.storagePath || '')

  const handlePrev = useCallback(
    (e?: React.MouseEvent) => {
      e?.stopPropagation()
      if (currentIndex > 0) onNavigate(currentIndex - 1)
    },
    [currentIndex, onNavigate]
  )

  const handleNext = useCallback(
    (e?: React.MouseEvent) => {
      e?.stopPropagation()
      if (currentIndex < images.length - 1) onNavigate(currentIndex + 1)
    },
    [currentIndex, images.length, onNavigate]
  )

  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'Escape') onClose()
      if (e.key === 'ArrowLeft') handlePrev()
      if (e.key === 'ArrowRight') handleNext()
    }
    window.addEventListener('keydown', handleKeyDown)
    return () => window.removeEventListener('keydown', handleKeyDown)
  }, [onClose, handlePrev, handleNext])

  if (!currentImage) return null

  return (
    <div className="image-gallery-modal" onClick={onClose}>
      <button className="gallery-close-btn" onClick={onClose} title="닫기" aria-label="닫기">
        <Icon name="x" size={20} />
      </button>

      <div className="gallery-main" onClick={(e) => e.stopPropagation()}>
        {currentIndex > 0 && (
          <button className="gallery-nav-btn gallery-prev" onClick={handlePrev}>
            ‹
          </button>
        )}

        <div className="gallery-image-container">
          {url ? (
            <img src={url} alt={currentImage.filename || '이미지'} />
          ) : (
            <div className="gallery-loading">로딩 중...</div>
          )}
        </div>

        {currentIndex < images.length - 1 && (
          <button className="gallery-nav-btn gallery-next" onClick={handleNext}>
            ›
          </button>
        )}
      </div>

      {images.length > 1 && (
        <div className="gallery-thumbnails" onClick={(e) => e.stopPropagation()}>
          {images.map((img, idx) => (
            <GalleryThumbnail
              key={img.id}
              attachment={img}
              isActive={idx === currentIndex}
              onClick={() => onNavigate(idx)}
            />
          ))}
        </div>
      )}

      <div className="gallery-counter">
        {currentIndex + 1} / {images.length}
      </div>
    </div>
  )
}

function GalleryThumbnail({
  attachment,
  isActive,
  onClick,
}: {
  attachment: Attachment
  isActive: boolean
  onClick: () => void
}) {
  const { url } = useAttachmentUrl(attachment.storagePath)

  return (
    <button
      className={`gallery-thumbnail ${isActive ? 'active' : ''}`}
      onClick={onClick}
    >
      {url ? (
        <img src={url} alt={attachment.filename || ''} />
      ) : (
        <div className="gallery-thumbnail-loading" />
      )}
    </button>
  )
}

function ImageAttachment({
  attachment,
  onRemove,
  onExpand,
}: {
  attachment: Attachment
  /** 없으면 삭제 버튼을 그리지 않는다 — 읽기 전용 viewer(BRU-59) 경로 */
  onRemove?: () => void
  onExpand: () => void
}) {
  const [hasError, setHasError] = useState(false)
  const { url, retry } = useAttachmentUrl(attachment.storagePath)

  const handleError = () => {
    console.error('[attachments] image load failed', {
      attachmentId: attachment.id,
      storagePath: attachment.storagePath,
      url,
    })
    setHasError(true)
  }

  const handleRetry = (e: React.MouseEvent) => {
    e.stopPropagation()
    setHasError(false)
    retry()
  }

  const handleClick = () => {
    if (!hasError && url) onExpand()
  }

  return (
    <div className="attachment-card attachment-image">
      {onRemove && (
        <button className="attachment-remove" onClick={onRemove} title="첨부 삭제" aria-label="첨부 삭제"><Icon name="x" size={12} /></button>
      )}
      <div className="attachment-thumbnail" onClick={handleClick}>
        {hasError ? (
          <div className="attachment-error" onClick={handleRetry}>
            <span>로드 실패</span>
            <button>재시도</button>
          </div>
        ) : url ? (
          <img src={url} alt={attachment.filename || '이미지'} onError={handleError} />
        ) : (
          <span className="attachment-placeholder">로딩 중</span>
        )}
      </div>
    </div>
  )
}

function VideoAttachment({
  attachment,
  onRemove,
}: {
  attachment: Attachment
  /** 없으면 삭제 버튼을 그리지 않는다 — 읽기 전용 viewer(BRU-59) 경로 */
  onRemove?: () => void
}) {
  const [hasError, setHasError] = useState(false)
  const { url, retry } = useAttachmentUrl(attachment.storagePath)

  const handleRetry = () => {
    setHasError(false)
    retry()
  }

  return (
    <div className="attachment-card attachment-video">
      {onRemove && (
        <button className="attachment-remove" onClick={onRemove} title="첨부 삭제" aria-label="첨부 삭제"><Icon name="x" size={12} /></button>
      )}
      {hasError ? (
        <div className="attachment-error" onClick={handleRetry}>
          <span>로드 실패</span>
          <button>재시도</button>
        </div>
      ) : url ? (
        <video
          className="attachment-video-player"
          controls
          src={url}
          onError={() => setHasError(true)}
        />
      ) : (
        <span className="attachment-placeholder">로딩 중</span>
      )}
    </div>
  )
}

function AudioAttachment({
  attachment,
  onRemove,
}: {
  attachment: Attachment
  /** 없으면 삭제 버튼을 그리지 않는다 — 읽기 전용 viewer(BRU-59) 경로 */
  onRemove?: () => void
}) {
  const [hasError, setHasError] = useState(false)
  const { url, retry } = useAttachmentUrl(attachment.storagePath)

  const handleRetry = () => {
    setHasError(false)
    retry()
  }

  return (
    <div className="attachment-card attachment-audio">
      {onRemove && (
        <button className="attachment-remove" onClick={onRemove} title="첨부 삭제" aria-label="첨부 삭제"><Icon name="x" size={12} /></button>
      )}
      {hasError ? (
        <div className="attachment-error" onClick={handleRetry}>
          <span>로드 실패</span>
          <button>재시도</button>
        </div>
      ) : url ? (
        <audio
          className="attachment-audio-player"
          controls
          src={url}
          onError={() => setHasError(true)}
        />
      ) : (
        <span className="attachment-placeholder">로딩 중</span>
      )}
    </div>
  )
}

function FileAttachment({
  attachment,
  onRemove,
}: {
  attachment: Attachment
  /** 없으면 삭제 버튼을 그리지 않는다 — 읽기 전용 viewer(BRU-59) 경로 */
  onRemove?: () => void
}) {
  const { url } = useAttachmentUrl(attachment.storagePath)

  const handleDownload = () => {
    if (!url) return
    const link = document.createElement('a')
    link.href = url
    link.download = attachment.filename || 'download'
    link.click()
  }

  const ext = getExtension(attachment.filename, attachment.mimeType)
  const styles = defaultStyles[ext as keyof typeof defaultStyles] || {}

  return (
    <div className="attachment-card attachment-file">
      {onRemove && (
        <button className="attachment-remove" onClick={onRemove} title="첨부 삭제" aria-label="첨부 삭제"><Icon name="x" size={12} /></button>
      )}
      <div className="attachment-file-content" onClick={handleDownload}>
        <div className="attachment-file-icon">
          <FileIcon extension={ext} {...styles} />
        </div>
        <div className="attachment-file-info">
          <span className="attachment-file-name">{attachment.filename || '파일'}</span>
          <span className="attachment-file-size">{formatFileSize(attachment.size)}</span>
        </div>
      </div>
    </div>
  )
}

function TextAttachment({
  attachment,
  onRemove,
}: {
  attachment: Attachment
  /** 없으면 삭제 버튼을 그리지 않는다 — 읽기 전용 viewer(BRU-59) 경로 */
  onRemove?: () => void
}) {
  const [expanded, setExpanded] = useState(false)
  const [content, setContent] = useState<string | null>(null)
  const { url } = useAttachmentUrl(attachment.storagePath)

  useEffect(() => {
    if (!url) return
    fetch(url)
      .then((res) => res.text())
      .then(setContent)
      .catch(() => setContent(null))
  }, [url])

  const lineCount = content?.split('\n').length ?? 0
  const preview = content?.split('\n').slice(0, 3).join('\n') ?? ''

  return (
    <div className="attachment-card attachment-text">
      {onRemove && (
        <button className="attachment-remove" onClick={onRemove} title="첨부 삭제" aria-label="첨부 삭제"><Icon name="x" size={12} /></button>
      )}
      <div className="attachment-text-content" onClick={() => setExpanded(true)}>
        <div className="attachment-text-header">
          <span className="attachment-text-icon">
            <Icon name="file-text" size={14} />
          </span>
          <span className="attachment-text-name">{attachment.filename || '텍스트'}</span>
          <span className="attachment-text-meta">{lineCount}줄 · {formatFileSize(attachment.size)}</span>
        </div>
        <pre className="attachment-text-preview">{preview}{lineCount > 3 ? '\n...' : ''}</pre>
      </div>
      {expanded && content ? (
        <div className="attachment-modal" onClick={() => setExpanded(false)}>
          <div className="attachment-text-dialog" onClick={(e) => e.stopPropagation()}>
            <div className="attachment-text-dialog-header">
              {attachment.filename || '텍스트'}
              <button onClick={() => setExpanded(false)} title="닫기" aria-label="닫기">
                <Icon name="x" size={14} />
              </button>
            </div>
            <pre className="attachment-text-full">{content}</pre>
          </div>
        </div>
      ) : null}
    </div>
  )
}

function YouTubeAttachment({
  attachment,
  onRemove,
}: {
  attachment: Attachment
  /** 없으면 삭제 버튼을 그리지 않는다 — 읽기 전용 viewer(BRU-59) 경로 */
  onRemove?: () => void
}) {
  const isLoading = attachment.metadata?.loading === true
  const [hasError, setHasError] = useState(false)
  const title = attachment.caption?.trim()
  const authorName = attachment.authorName?.trim()
  const originalUrl = attachment.originalUrl
  const authorUrl = attachment.authorUrl
  const videoId = attachment.metadata?.videoId as string | undefined
  const thumbnailUrl = attachment.metadata?.thumbnailUrl as string | undefined

  // 썸네일 URL 결정 (metadata에서 가져오거나 videoId로 생성)
  const getThumbnailUrl = () => {
    if (thumbnailUrl) return thumbnailUrl
    if (videoId) return `https://i.ytimg.com/vi/${videoId}/hqdefault.jpg`
    return null
  }

  const openUrl = (target?: string) => {
    if (!target) return
    window.api.openExternal(target)
  }

  // 로딩 중인 경우 skeleton 표시
  if (isLoading) {
    return (
      <div className="attachment-card attachment-youtube attachment-loading">
        <div className="attachment-youtube-content">
          <div className="attachment-youtube-thumbnail">
            <div className="attachment-skeleton" />
          </div>
          <div className="attachment-youtube-info">
            <div className="attachment-youtube-header">
              <span className="attachment-youtube-icon" aria-hidden="true">
                <Icon name="youtube" size={14} />
              </span>
              <span className="attachment-youtube-label">YouTube</span>
            </div>
            <span className="attachment-skeleton-text" />
          </div>
        </div>
      </div>
    )
  }

  const thumbUrl = getThumbnailUrl()

  return (
    <div className="attachment-card attachment-youtube">
      {onRemove && (
        <button className="attachment-remove" onClick={onRemove} title="첨부 삭제" aria-label="첨부 삭제"><Icon name="x" size={12} /></button>
      )}
      <div
        className="attachment-youtube-content"
        onClick={() => openUrl(originalUrl)}
      >
        <div className="attachment-youtube-thumbnail">
          {hasError || !thumbUrl ? (
            <div className="attachment-youtube-placeholder">
              <Icon name="youtube" size={48} style={{ opacity: 0.5 }} />
            </div>
          ) : (
            <>
              <img
                src={thumbUrl}
                alt={title || 'YouTube'}
                onError={() => setHasError(true)}
              />
              <div className="attachment-youtube-play">
                <Icon name="play" size={48} fill="#fff" stroke="none" />
              </div>
            </>
          )}
        </div>
        <div className="attachment-youtube-info">
          <div className="attachment-youtube-header">
            <span className="attachment-youtube-icon" aria-hidden="true">
              <Icon name="youtube" size={14} />
            </span>
            <span className="attachment-youtube-label">YouTube</span>
          </div>
          {title ? <p className="attachment-youtube-title">{title}</p> : null}
          {authorName ? (
            <span
              className="attachment-youtube-author"
              onClick={(event) => {
                event.stopPropagation()
                openUrl(authorUrl)
              }}
            >
              {authorName}
            </span>
          ) : null}
        </div>
      </div>
    </div>
  )
}

function InstagramAttachment({
  attachment,
  onRemove,
}: {
  attachment: Attachment
  /** 없으면 삭제 버튼을 그리지 않는다 — 읽기 전용 viewer(BRU-59) 경로 */
  onRemove?: () => void
}) {
  const isLoading = attachment.metadata?.loading === true
  const { url, retry } = useAttachmentUrl(attachment.storagePath)
  const [expanded, setExpanded] = useState(false)
  const [hasError, setHasError] = useState(false)
  const caption = attachment.caption?.trim()
  const authorName = attachment.authorName?.trim()
  const originalUrl = attachment.originalUrl
  const authorUrl = attachment.authorUrl
  const metadata = {
    originalUrl,
    authorName,
    authorUrl,
    caption,
    ...(attachment.metadata ?? {}),
  }
  const metadataText = JSON.stringify(metadata, null, 2)

  const openUrl = (target?: string) => {
    if (!target) return
    window.api.openExternal(target)
  }

  const handleRetry = (e: React.MouseEvent) => {
    e.stopPropagation()
    setHasError(false)
    retry()
  }

  // 로딩 중인 경우 skeleton 표시
  if (isLoading) {
    return (
      <div className="attachment-card attachment-instagram attachment-loading">
        <div className="attachment-instagram-content">
          <div className="attachment-instagram-thumbnail">
            <div className="attachment-skeleton" />
          </div>
          <div className="attachment-instagram-info">
            <div className="attachment-instagram-header">
              <span className="attachment-instagram-icon" aria-hidden="true">
                <Icon name="instagram" size={14} />
              </span>
              <span className="attachment-instagram-label">Instagram</span>
            </div>
            <span className="attachment-skeleton-text" />
          </div>
        </div>
      </div>
    )
  }

  return (
    <div className="attachment-card attachment-instagram">
      {onRemove && (
        <button className="attachment-remove" onClick={onRemove} title="첨부 삭제" aria-label="첨부 삭제"><Icon name="x" size={12} /></button>
      )}
      <div className="attachment-instagram-content" onClick={() => !hasError && setExpanded(true)}>
        <div className="attachment-instagram-thumbnail">
          {hasError ? (
            <div className="attachment-error" onClick={handleRetry}>
              <span>로드 실패</span>
              <button>재시도</button>
            </div>
          ) : url ? (
            <img
              src={url}
              alt={attachment.filename || 'Instagram'}
              onError={() => setHasError(true)}
            />
          ) : (
            <span className="attachment-placeholder">로딩 중</span>
          )}
        </div>
        <div className="attachment-instagram-info">
          <div className="attachment-instagram-header">
            <span className="attachment-instagram-icon" aria-hidden="true">
              <Icon name="instagram" size={14} />
            </span>
            <span className="attachment-instagram-label">Instagram</span>
          </div>
          {authorName ? (
            <span
              className="attachment-instagram-author"
              onClick={(event) => {
                event.stopPropagation()
                openUrl(authorUrl ?? originalUrl)
              }}
            >
              @{authorName}
            </span>
          ) : null}
          {caption ? <p className="attachment-instagram-caption">{caption}</p> : null}
          {originalUrl ? (
            <span
              className="attachment-instagram-hint"
              onClick={(event) => {
                event.stopPropagation()
                openUrl(originalUrl)
              }}
            >
              원본 보기
            </span>
          ) : null}
        </div>
      </div>
      {expanded ? (
        <div className="attachment-modal" onClick={() => setExpanded(false)}>
          <div
            className="attachment-instagram-dialog"
            onClick={(event) => event.stopPropagation()}
          >
            <div className="attachment-instagram-dialog-header">Instagram 파싱 데이터</div>
            <pre className="attachment-instagram-json">{metadataText}</pre>
          </div>
        </div>
      ) : null}
    </div>
  )
}

export function AttachmentList({ attachments, onRemove, maxVisible, onShowMore }: Props) {
  const [galleryIndex, setGalleryIndex] = useState<number | null>(null)

  // 모든 이미지 첨부파일 (갤러리용)
  const imageAttachments = useMemo(
    () => attachments.filter((a) => a.type === 'image'),
    [attachments]
  )

  const handleImageExpand = useCallback(
    (attachmentId: string) => {
      const index = imageAttachments.findIndex((a) => a.id === attachmentId)
      if (index !== -1) setGalleryIndex(index)
    },
    [imageAttachments]
  )

  const closeGallery = useCallback(() => setGalleryIndex(null), [])

  if (attachments.length === 0) return null

  const visibleAttachments = maxVisible ? attachments.slice(0, maxVisible) : attachments
  const hiddenCount = maxVisible ? Math.max(0, attachments.length - maxVisible) : 0

  return (
    <div className="attachment-list">
      {visibleAttachments.map((attachment) => {
        switch (attachment.type) {
          case 'image':
            return (
              <ImageAttachment
                key={attachment.id}
                attachment={attachment}
                onRemove={onRemove ? () => onRemove(attachment.id) : undefined}
                onExpand={() => handleImageExpand(attachment.id)}
              />
            )
          case 'video':
            return (
              <VideoAttachment
                key={attachment.id}
                attachment={attachment}
                onRemove={onRemove ? () => onRemove(attachment.id) : undefined}
              />
            )
          case 'audio':
            return (
              <AudioAttachment
                key={attachment.id}
                attachment={attachment}
                onRemove={onRemove ? () => onRemove(attachment.id) : undefined}
              />
            )
          case 'file':
            return (
              <FileAttachment
                key={attachment.id}
                attachment={attachment}
                onRemove={onRemove ? () => onRemove(attachment.id) : undefined}
              />
            )
          case 'text':
            return (
              <TextAttachment
                key={attachment.id}
                attachment={attachment}
                onRemove={onRemove ? () => onRemove(attachment.id) : undefined}
              />
            )
          case 'instagram':
            return (
              <InstagramAttachment
                key={attachment.id}
                attachment={attachment}
                onRemove={onRemove ? () => onRemove(attachment.id) : undefined}
              />
            )
          case 'youtube':
            return (
              <YouTubeAttachment
                key={attachment.id}
                attachment={attachment}
                onRemove={onRemove ? () => onRemove(attachment.id) : undefined}
              />
            )
          default:
            return null
        }
      })}
      {hiddenCount > 0 && onShowMore && (
        <button className="attachment-more-btn" onClick={onShowMore}>
          +{hiddenCount}개 더보기
        </button>
      )}
      {galleryIndex !== null && imageAttachments.length > 0 && (
        <ImageGalleryModal
          images={imageAttachments}
          currentIndex={galleryIndex}
          onClose={closeGallery}
          onNavigate={setGalleryIndex}
        />
      )}
    </div>
  )
}
