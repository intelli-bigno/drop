import { useState, useRef, useEffect, useCallback } from 'react'
import { useAuthStore } from '../stores/auth'
import { useNotesStore } from '../stores/notes'
import { extractInstagramUrls } from '../lib/instagram-url-utils'
import { extractYouTubeUrls } from '../lib/youtube-url-utils'
import { Icon, type IconName } from './Icon'
import '../styles/quick-capture.css'

// 큰 텍스트 임계값 (둘 다 충족해야 텍스트 첨부파일로 처리)
const LARGE_TEXT_THRESHOLD_LINES = 20
const LARGE_TEXT_THRESHOLD_CHARS = 1000

interface PendingAttachment {
  type: 'file' | 'image' | 'text' | 'instagram' | 'youtube'
  name: string
  file?: File
  url?: string
}

export function QuickCapture() {
  const [content, setContent] = useState('')
  const [isSubmitting, setIsSubmitting] = useState(false)
  const [showSuccess, setShowSuccess] = useState(false)
  const [pendingAttachments, setPendingAttachments] = useState<PendingAttachment[]>([])
  const inputRef = useRef<HTMLTextAreaElement>(null)
  const { user, initializeAuth } = useAuthStore()
  const { createNote, addAttachment, createNoteWithInstagram, createNoteWithYouTube, updateNote } =
    useNotesStore()

  // Log component mount
  useEffect(() => {
    console.log('[QuickCapture] Component mounted')
    return () => console.log('[QuickCapture] Component unmounted')
  }, [])

  // Log user state changes
  useEffect(() => {
    console.log('[QuickCapture] User state changed:', user?.id ?? 'null')
  }, [user])

  // Initialize auth on mount
  useEffect(() => {
    console.log('[QuickCapture] Initializing auth...')
    initializeAuth()
  }, [initializeAuth])

  // Auto focus on mount and whenever window regains visibility
  // Also reset state when window becomes visible (since window is hidden, not destroyed)
  useEffect(() => {
    const focusInput = () => {
      setTimeout(() => {
        inputRef.current?.focus()
      }, 50)
    }
    focusInput()

    // Reset state and focus when window becomes visible
    const handleVisibilityChange = () => {
      if (document.visibilityState === 'visible') {
        console.log('[QuickCapture] Window became visible, resetting state')
        setShowSuccess(false)
        setIsSubmitting(false)
        setContent('')
        setPendingAttachments([])
        focusInput()
      }
    }
    document.addEventListener('visibilitychange', handleVisibilityChange)
    return () => document.removeEventListener('visibilitychange', handleVisibilityChange)
  }, [])

  // 성공 후 창 닫기 + 메인 윈도우 refresh 알림
  const handleSuccess = useCallback(() => {
    console.log('[QuickCapture] handleSuccess - closing window in 200ms')
    setShowSuccess(true)
    setContent('')
    setPendingAttachments([])
    setTimeout(() => {
      console.log('[QuickCapture] Closing window now')
      window.api.quickCapture.close()
    }, 200)
  }, [])

  // Paste 핸들러 - attachment를 pending 상태로 추가
  const handlePaste = useCallback(
    (e: React.ClipboardEvent) => {
      console.log('[QuickCapture] handlePaste triggered')
      console.log('[QuickCapture] user:', user?.id, 'isSubmitting:', isSubmitting)

      if (!user || isSubmitting) {
        console.log('[QuickCapture] Paste blocked: user or isSubmitting')
        return
      }

      const items = e.clipboardData?.items
      console.log('[QuickCapture] Clipboard items count:', items?.length)
      if (!items) return

      // 파일/이미지 처리
      for (let i = 0; i < items.length; i++) {
        const item = items[i]
        console.log(`[QuickCapture] Item ${i}: kind=${item.kind}, type=${item.type}`)

        if (item.kind === 'file') {
          const file = item.getAsFile()
          if (!file) {
            console.log('[QuickCapture] File item but getAsFile() returned null')
            continue
          }

          console.log('[QuickCapture] File detected:', file.name, file.type, file.size)
          e.preventDefault()
          const isImage = file.type.startsWith('image/')
          const attachment = {
            type: isImage ? 'image' : 'file',
            name: file.name || (isImage ? '이미지' : '파일'),
            file,
          } as PendingAttachment
          console.log('[QuickCapture] Adding file attachment:', attachment.type, attachment.name)
          setPendingAttachments((prev) => [...prev, attachment])
          return
        }
      }

      // 텍스트 처리
      const text = e.clipboardData?.getData('text/plain')
      console.log('[QuickCapture] Text content length:', text?.length)
      if (text) {
        console.log('[QuickCapture] Text preview:', text.slice(0, 100))

        // Instagram URL 처리
        const instagramUrls = extractInstagramUrls(text)
        console.log('[QuickCapture] Instagram URLs found:', instagramUrls.length, instagramUrls)
        if (instagramUrls.length > 0) {
          e.preventDefault()
          for (const url of instagramUrls) {
            console.log('[QuickCapture] Adding Instagram attachment:', url)
            setPendingAttachments((prev) => [
              ...prev,
              { type: 'instagram', name: 'Instagram', url },
            ])
          }
          return
        }

        // YouTube URL 처리
        const youtubeUrls = extractYouTubeUrls(text)
        console.log('[QuickCapture] YouTube URLs found:', youtubeUrls.length, youtubeUrls)
        if (youtubeUrls.length > 0) {
          e.preventDefault()
          for (const url of youtubeUrls) {
            console.log('[QuickCapture] Adding YouTube attachment:', url)
            setPendingAttachments((prev) => [...prev, { type: 'youtube', name: 'YouTube', url }])
          }
          return
        }

        // 큰 텍스트는 텍스트 첨부파일로 처리
        const lineCount = text.split('\n').length
        const isLargeText =
          lineCount >= LARGE_TEXT_THRESHOLD_LINES && text.length >= LARGE_TEXT_THRESHOLD_CHARS
        console.log('[QuickCapture] Text analysis: lines=', lineCount, 'chars=', text.length, 'isLargeText=', isLargeText)
        console.log('[QuickCapture] Thresholds: lines>=', LARGE_TEXT_THRESHOLD_LINES, 'AND chars>=', LARGE_TEXT_THRESHOLD_CHARS)

        if (isLargeText) {
          e.preventDefault()
          const firstLine = text.split('\n')[0].slice(0, 30)
          const title = firstLine || `텍스트 (${lineCount}줄)`
          const textFile = new File([text], `${title}.txt`, { type: 'text/plain' })
          console.log('[QuickCapture] Adding large text attachment:', title)
          setPendingAttachments((prev) => [...prev, { type: 'text', name: title, file: textFile }])
          return
        }

        // 짧은 텍스트는 기존 content에 추가 (기본 동작 허용)
        console.log('[QuickCapture] Short text - allowing default paste behavior')
      }
    },
    [user, isSubmitting]
  )

  // attachment 제거
  const removeAttachment = useCallback((index: number) => {
    console.log('[QuickCapture] Removing attachment at index:', index)
    setPendingAttachments((prev) => {
      const newAttachments = prev.filter((_, i) => i !== index)
      console.log('[QuickCapture] Attachments after removal:', newAttachments.length)
      return newAttachments
    })
  }, [])

  const handleSubmit = async () => {
    console.log('[QuickCapture] handleSubmit called')
    console.log('[QuickCapture] content:', content.trim().slice(0, 50))
    console.log('[QuickCapture] pendingAttachments:', pendingAttachments.length, pendingAttachments.map(a => ({ type: a.type, name: a.name })))
    console.log('[QuickCapture] isSubmitting:', isSubmitting, 'user:', !!user)

    // content가 없어도 attachment가 있으면 저장 가능
    if ((!content.trim() && pendingAttachments.length === 0) || isSubmitting || !user) {
      console.log('[QuickCapture] Submit blocked: empty content/attachments or submitting or no user')
      return
    }

    setIsSubmitting(true)
    try {
      // pending attachments가 있으면 직접 처리
      if (pendingAttachments.length > 0) {
        console.log('[QuickCapture] Processing pending attachments...')

        // Instagram/YouTube는 특수 처리
        const instagramAttachments = pendingAttachments.filter((a) => a.type === 'instagram')
        const youtubeAttachments = pendingAttachments.filter((a) => a.type === 'youtube')
        const fileAttachments = pendingAttachments.filter(
          (a) => a.type === 'file' || a.type === 'image' || a.type === 'text'
        )
        console.log('[QuickCapture] Attachment breakdown: instagram=', instagramAttachments.length, 'youtube=', youtubeAttachments.length, 'files=', fileAttachments.length)

        // Instagram 처리
        for (const attachment of instagramAttachments) {
          if (attachment.url) {
            console.log('[QuickCapture] Creating Instagram note:', attachment.url)
            const note = await createNoteWithInstagram(attachment.url)
            console.log('[QuickCapture] Instagram note created:', note?.id)
            // content가 있으면 노트 내용 업데이트
            if (content.trim() && note) {
              console.log('[QuickCapture] Updating note with content')
              await updateNote(note.id, content.trim())
            }
          }
        }

        // YouTube 처리
        for (const attachment of youtubeAttachments) {
          if (attachment.url) {
            console.log('[QuickCapture] Creating YouTube note:', attachment.url)
            const note = await createNoteWithYouTube(attachment.url)
            console.log('[QuickCapture] YouTube note created:', note?.id)
            if (content.trim() && note) {
              console.log('[QuickCapture] Updating note with content')
              await updateNote(note.id, content.trim())
            }
          }
        }

        // 파일 처리
        if (fileAttachments.length > 0) {
          console.log('[QuickCapture] Creating note for file attachments')
          const note = await createNote(content.trim())
          console.log('[QuickCapture] Note created:', note.id)
          for (const attachment of fileAttachments) {
            if (attachment.file) {
              console.log('[QuickCapture] Adding attachment:', attachment.name, attachment.file.size)
              await addAttachment(note.id, attachment.file)
            }
          }
        }

        // 메인 윈도우에 refresh 알림
        console.log('[QuickCapture] Notifying main window to refresh')
        await window.api.quickCapture.notifyRefresh()
        handleSuccess()
      } else {
        // 텍스트만 있는 경우 기존 로직
        console.log('[QuickCapture] Text-only mode, using IPC submit')
        const result = await window.api.quickCapture.submit(content.trim())
        console.log('[QuickCapture] IPC submit result:', result)
        if (!result.handledByMainWindow) {
          console.log('[QuickCapture] Main window not available, creating note directly')
          await createNote(content.trim())
        }
        handleSuccess()
      }
    } catch (error) {
      console.error('[QuickCapture] Failed to create note:', error)
      setIsSubmitting(false)
    }
  }

  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === 'Escape') {
      e.preventDefault()
      window.api.quickCapture.close()
    } else if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault()
      handleSubmit()
    }
  }

  // Not authenticated
  if (!user) {
    return (
      <div className="quick-capture">
        <div className="quick-capture-panel">
          <div className="quick-capture-auth-message">
            Braindump app not logged in. Press ESC to close.
          </div>
        </div>
      </div>
    )
  }

  const getAttachmentIconName = (type: PendingAttachment['type']): IconName => {
    switch (type) {
      case 'image':
        return 'image'
      case 'file':
        return 'paperclip'
      case 'text':
        return 'file-text'
      case 'instagram':
        return 'camera'
      case 'youtube':
        return 'play'
      default:
        return 'paperclip'
    }
  }

  return (
    <div className="quick-capture">
      <div
        className={[
          'quick-capture-panel',
          showSuccess ? 'success' : '',
          pendingAttachments.length > 0 ? 'has-attachments' : '',
        ]
          .filter(Boolean)
          .join(' ')}
      >
        {/* Pending Attachments */}
        {pendingAttachments.length > 0 && (
          <div className="quick-capture-attachments">
            {pendingAttachments.map((attachment, index) => (
              <div key={index} className="quick-capture-chip">
                <span>
                  <Icon name={getAttachmentIconName(attachment.type)} size={12} />
                </span>
                <span className="quick-capture-chip-name">{attachment.name}</span>
                <button
                  className="quick-capture-chip-remove"
                  onClick={() => removeAttachment(index)}
                  disabled={isSubmitting}
                  title="첨부 삭제"
                  aria-label="첨부 삭제"
                >
                  <Icon name="x" size={10} />
                </button>
              </div>
            ))}
          </div>
        )}
        <div className="quick-capture-input-row">
          <textarea
            ref={inputRef}
            value={content}
            onChange={(e) => setContent(e.target.value)}
            onKeyDown={handleKeyDown}
            onPaste={handlePaste}
            placeholder={
              pendingAttachments.length > 0
                ? '추가 메모... (Enter to save)'
                : 'Quick note... (Enter to save, Esc to close)'
            }
            className="quick-capture-input"
            disabled={isSubmitting}
            rows={1}
          />
          {isSubmitting && <div className="quick-capture-spinner" />}
        </div>
      </div>
    </div>
  )
}
