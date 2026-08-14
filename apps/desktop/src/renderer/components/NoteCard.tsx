import { useRef, useCallback, forwardRef, useImperativeHandle, useState, memo, useMemo, useEffect } from 'react'
import { LexicalEditor, LexicalEditorHandle } from './LexicalEditor'
import { AttachmentList } from './AttachmentList'
import { LinkPreviews } from './LinkPreviews'
import { TagList } from './TagList'
import { LockedNoteOverlay } from './LockedNoteOverlay'
import { PinDialog, type PinDialogMode } from './PinDialog'
import { ConfirmDialog } from './ConfirmDialog'
import { Icon } from './Icon'
import { NoteHistoryDialog } from './NoteHistoryDialog'
import { useNotesStore } from '../stores/notes'
import { useProfileStore } from '../stores/profile'
import { formatRelativeTime } from '../lib/time-utils'
import { nextPriority, priorityClassName } from '../lib/note-priority'
import { toSingleLinePreview, countContentLinks } from '../lib/note-line'
import { resolveTrailingSlot, shouldPinStatusStayVisible } from '../lib/note-card-trailing'
import { useDragAndDrop } from '../hooks'
import type { Note } from '@drop/shared'
import type { NoteViewMode } from '../stores/notes/types'

interface Props {
  note: Note
  isFocused: boolean
  depth?: number
  viewMode?: NoteViewMode
  onEscapeFromNormal: () => void
  onReply?: (noteId: string) => void
}

export interface NoteCardHandle {
  focus: () => void
  openTagList: () => void
}

export const NoteCard = memo(
  forwardRef<NoteCardHandle, Props>(
    ({ note, isFocused, depth = 0, viewMode = 'active', onEscapeFromNormal, onReply }, ref) => {
      const editorRef = useRef<LexicalEditorHandle>(null)
      const pendingFocusRef = useRef(false)
      const [showPinDialog, setShowPinDialog] = useState(false)
      const [showPermanentDeleteConfirm, setShowPermanentDeleteConfirm] = useState(false)
      const [pinDialogMode, setPinDialogMode] = useState<PinDialogMode>('setup')
      const [isHovered, setIsHovered] = useState(false)

      const {
        updateNote,
        updateNotePriority,
        requestDeleteNote,
        addAttachment,
        removeAttachment,
        temporarilyUnlockedNoteIds,
        temporarilyUnlockNote,
        permanentlyUnlockNote,
        lockNote,
        archiveNote,
        unarchiveNote,
        restoreNote,
        permanentlyDeleteNote,
        togglePinNote,
        openHistory,
        closeHistory,
        historyNoteId,
      } = useNotesStore()
      const hasPin = useProfileStore((s) => s.hasPin)

      // DB에서 잠금 상태이고 + 일시 해제되지 않은 경우에만 잠김
      const isLocked = note.isLocked && !temporarilyUnlockedNoteIds.has(note.id)

      // 상태는 둘뿐이다 — 한 줄(보기) / 펼침(편집).
      // 카드를 클릭하면 NoteFeed가 focusedIndex를 옮기므로 클릭·키보드 이동이
      // 모두 같은 한 가지 신호(isFocused)로 들어온다.
      const isOpen = isFocused

      // 한 줄에 그릴 본문 — 잠긴 노트는 내용을 흘리지 않는다
      const previewText = useMemo(
        () => (isLocked ? '' : toSingleLinePreview(note.content)),
        [isLocked, note.content]
      )
      const linkCount = useMemo(
        () => (isLocked ? 0 : countContentLinks(note.content)),
        [isLocked, note.content]
      )
      const attachmentCount = isLocked ? 0 : note.attachments.length

      const trailingSlot = resolveTrailingSlot({ isHovered, isFocused })
      const showStatusIcons = shouldPinStatusStayVisible({
        isPinned: note.isPinned,
        isLocked: note.isLocked,
      })

      const handleAddFile = useCallback(
        (file: File) => {
          addAttachment(note.id, file)
        },
        [note.id, addAttachment]
      )

      const { isDragOver, handleDragOver, handleDragLeave, handleDrop } = useDragAndDrop({
        onDrop: (files) => files.forEach(handleAddFile),
      })

      useImperativeHandle(ref, () => ({
        focus: () => {
          // 카드가 아직 접혀 있으면 에디터가 없다 — 펼쳐진 다음 잡도록 예약한다
          pendingFocusRef.current = true
          editorRef.current?.focus()
        },
        // BRU-46에서 카드 안 태그 입력칸(TagInput)이 빠졌다. 태그 추가는 NoteFeed의
        // t 단축키가 여는 TagDialog가 담당하므로 카드가 열 UI는 없다.
        // 인터페이스는 호출부 호환을 위해 남긴다 — 태그 입력 재설계는 BRU-44.
        openTagList: () => undefined,
      }))

      // 펼쳐진 뒤에 예약된 포커스를 소비한다
      useEffect(() => {
        if (!isOpen) return
        if (!pendingFocusRef.current) return
        pendingFocusRef.current = false
        editorRef.current?.focus()
      }, [isOpen])

      const handleChange = useCallback(
        (content: string) => {
          // 동일한 content면 업데이트 스킵 (초기 렌더링 시 불필요한 호출 방지)
          if (content === note.content) return
          updateNote(note.id, content)
        },
        [note.id, note.content, updateNote]
      )

      const handleRemoveAttachment = useCallback(
        (attachmentId: string) => {
          removeAttachment(note.id, attachmentId)
        },
        [note.id, removeAttachment]
      )

      const indentStyle = depth > 0 ? { marginLeft: `${depth * 24}px` } : undefined

      // 헤더의 잠금 버튼 클릭: 잠금 설정 또는 완전 해제
      const handleLockToggle = () => {
        if (!note.isLocked && !hasPin) {
          // PIN이 없으면 먼저 설정하도록 유도
          setPinDialogMode('setup')
          setShowPinDialog(true)
          return
        }
        // 잠금 해제하려면 PIN 확인 필요 (완전 해제)
        if (note.isLocked) {
          setPinDialogMode('unlock-permanent')
          setShowPinDialog(true)
          return
        }
        // 잠금 설정 (이미 PIN이 있는 경우)
        lockNote(note.id)
      }

      // 일시 해제 버튼 클릭
      const handleTemporaryUnlock = () => {
        setPinDialogMode('unlock-temp')
        setShowPinDialog(true)
      }

      // 완전 해제 버튼 클릭
      const handlePermanentUnlock = () => {
        setPinDialogMode('unlock-permanent')
        setShowPinDialog(true)
      }

      const handlePinSuccess = () => {
        setShowPinDialog(false)
        switch (pinDialogMode) {
          case 'setup':
            lockNote(note.id)
            break
          case 'unlock-temp':
            temporarilyUnlockNote(note.id)
            break
          case 'unlock-permanent':
            permanentlyUnlockNote(note.id)
            break
        }
      }

      const handlePriorityClick = (e: React.MouseEvent) => {
        e.stopPropagation()
        updateNotePriority(note.id, nextPriority(note.priority))
      }

      const cardClassName = ['note-card', isFocused && 'focused', isDragOver && 'drag-over', depth > 0 && 'note-card-reply', isLocked && 'locked', isOpen ? 'open' : 'one-line']
        .filter(Boolean)
        .join(' ')

      return (
        <>
          <div
            className={cardClassName}
            style={indentStyle}
            data-note-id={note.id}
            onMouseEnter={() => setIsHovered(true)}
            onMouseLeave={() => setIsHovered(false)}
            onDragOver={isLocked ? undefined : handleDragOver}
            onDragLeave={isLocked ? undefined : handleDragLeave}
            onDrop={isLocked ? undefined : handleDrop}
          >
            <div className="note-line">
              {viewMode === 'active' && (
                <button
                  className={`priority-dot ${priorityClassName(note.priority)}`}
                  onClick={handlePriorityClick}
                  title={`긴급도 ${note.priority}/3 (클릭하면 순환)`}
                  aria-label={`긴급도 ${note.priority}/3`}
                />
              )}
              <span className="note-id">#{note.displayId}</span>
              <span className="note-line-content">
                {isOpen ? null : isLocked ? (
                  <span className="note-line-placeholder">잠긴 노트</span>
                ) : previewText ? (
                  previewText
                ) : (
                  <span className="note-line-placeholder">빈 노트</span>
                )}
              </span>
              {!isOpen && (attachmentCount > 0 || linkCount > 0) && (
                <span className="note-line-counts">
                  {attachmentCount > 0 && (
                    <span className="note-line-count" title={`첨부 ${attachmentCount}개`}>
                      <Icon name="paperclip" size={11} />
                      {attachmentCount}
                    </span>
                  )}
                  {linkCount > 0 && (
                    <span className="note-line-count" title={`링크 ${linkCount}개`}>
                      <Icon name="link" size={11} />
                      {linkCount}
                    </span>
                  )}
                </span>
              )}
              <div className="note-line-tags">
                <TagList noteId={note.id} tags={note.tags} />
              </div>
              <div className="note-card-trailing" data-slot={trailingSlot}>
                {showStatusIcons && (
                  <span className="note-line-status" aria-hidden="true">
                    {note.isPinned && <Icon name="pin" size={12} />}
                    {note.isLocked && <Icon name="lock" size={12} />}
                  </span>
                )}
                <span className="note-time">{formatRelativeTime(note.createdAt)}</span>
                <div className="note-card-actions" onClick={(e) => e.stopPropagation()}>
                  {viewMode === 'active' && (
                    <>
                      <button
                        className={`pin-btn ${note.isPinned ? 'pinned' : ''}`}
                        onClick={() => togglePinNote(note.id)}
                        title={note.isPinned ? '고정 해제 (p)' : '상단 고정 (p)'}
                        aria-label={note.isPinned ? '고정 해제' : '상단 고정'}
                      >
                        <Icon name="pin" />
                      </button>
                      <button
                        className={`lock-btn ${note.isLocked ? 'locked' : ''}`}
                        onClick={handleLockToggle}
                        title={note.isLocked ? '잠금 해제' : '잠금'}
                        aria-label={note.isLocked ? '잠금 해제' : '잠금'}
                      >
                        <Icon name={note.isLocked ? 'lock' : 'lock-open'} />
                      </button>
                      {onReply && !isLocked && (
                        <button
                          className="reply-btn"
                          onClick={() => onReply(note.id)}
                          title="답글"
                          aria-label="답글"
                        >
                          <Icon name="corner-up-left" />
                        </button>
                      )}
                      {!isLocked && (
                        <button
                          className="history-btn"
                          onClick={() => openHistory(note.id)}
                          title="편집 기록"
                          aria-label="편집 기록"
                        >
                          <Icon name="history" />
                        </button>
                      )}
                      {!isLocked && (
                        <button
                          className="archive-btn"
                          onClick={() => archiveNote(note.id)}
                          title="보관"
                          aria-label="보관"
                        >
                          <Icon name="archive" />
                        </button>
                      )}
                      {!isLocked && (
                        <button
                          className="delete-btn"
                          title="삭제"
                          aria-label="삭제"
                          onClick={() => requestDeleteNote(note.id)}
                        >
                          <Icon name="x" />
                        </button>
                      )}
                    </>
                  )}
                  {viewMode === 'archived' && (
                    <>
                      <button
                        className="unarchive-btn"
                        onClick={() => unarchiveNote(note.id)}
                        title="보관 해제"
                        aria-label="보관 해제"
                      >
                        <Icon name="corner-up-left" />
                      </button>
                      <button
                        className="delete-btn"
                        title="삭제"
                        aria-label="삭제"
                        onClick={() => requestDeleteNote(note.id)}
                      >
                        <Icon name="x" />
                      </button>
                    </>
                  )}
                  {viewMode === 'trash' && (
                    <>
                      <button
                        className="restore-btn"
                        onClick={() => restoreNote(note.id)}
                        title="복원"
                        aria-label="복원"
                      >
                        <Icon name="corner-up-left" />
                      </button>
                      <button
                        className="permanent-delete-btn"
                        onClick={() => setShowPermanentDeleteConfirm(true)}
                        title="영구 삭제"
                        aria-label="영구 삭제"
                      >
                        <Icon name="trash" />
                      </button>
                    </>
                  )}
                </div>
              </div>
            </div>
            {isOpen &&
              (isLocked ? (
                <LockedNoteOverlay
                  onTemporaryUnlock={handleTemporaryUnlock}
                  onPermanentUnlock={handlePermanentUnlock}
                />
              ) : (
                <>
                  <div className="note-editor">
                    <LexicalEditor
                      key={note.id}
                      ref={editorRef}
                      initialContent={note.content}
                      onChange={handleChange}
                      onEscape={onEscapeFromNormal}
                      onAddFile={handleAddFile}
                    />
                  </div>
                  <AttachmentList
                    attachments={note.attachments}
                    onRemove={handleRemoveAttachment}
                  />
                  <LinkPreviews content={note.content} attachments={note.attachments} />
                </>
              ))}
          </div>
          {showPinDialog && (
            <PinDialog
              mode={pinDialogMode}
              onSuccess={handlePinSuccess}
              onCancel={() => setShowPinDialog(false)}
            />
          )}
          {showPermanentDeleteConfirm && (
            <ConfirmDialog
              title="영구 삭제"
              message="이 노트를 영구 삭제하시겠습니까? 복원할 수 없습니다."
              confirmLabel="영구 삭제"
              danger
              onConfirm={() => {
                setShowPermanentDeleteConfirm(false)
                permanentlyDeleteNote(note.id)
              }}
              onCancel={() => setShowPermanentDeleteConfirm(false)}
            />
          )}
          {historyNoteId === note.id && (
            <NoteHistoryDialog noteId={note.id} onClose={closeHistory} />
          )}
        </>
      )
    }
  )
)

NoteCard.displayName = 'NoteCard'
