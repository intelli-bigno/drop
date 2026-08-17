import { useRef, useCallback, forwardRef, useImperativeHandle, useState, memo, useMemo, useEffect } from 'react'
import { LexicalEditor, LexicalEditorHandle } from './LexicalEditor'
import { AttachmentList } from './AttachmentList'
import { LinkPreviews } from './LinkPreviews'
import { TagList } from './TagList'
import { TagPopover } from './TagPopover'
import { TemplatePopover } from './TemplatePopover'
import { LockedNoteOverlay } from './LockedNoteOverlay'
import { PinDialog, type PinDialogMode } from './PinDialog'
import { ConfirmDialog } from './ConfirmDialog'
import { Icon } from './Icon'
import { NoteHistoryDialog } from './NoteHistoryDialog'
import { CommentPanel } from './CommentPanel'
import { useNotesStore } from '../stores/notes'
import { useProfileStore } from '../stores/profile'
import { formatRelativeTime } from '../lib/time-utils'
import { nextPriority, priorityClassName } from '../lib/note-priority'
import { toSingleLinePreview, countContentLinks } from '../lib/note-line'
import { resolveTrailingSlot, shouldPinStatusStayVisible } from '../lib/note-card-trailing'
import { shouldOpenTagPopoverOnEditEnd } from '../lib/tag-popover'
import { isEditorOpen } from '../lib/note-edit-mode'
import { shouldOpenTemplateMenu, type NoteTemplate } from '../lib/note-templates'
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
  /**
   * 태그 팝오버가 열리고 닫힐 때 알린다 (BRU-50).
   * Inbox 필터가 태그를 다는 동안 이 노트를 목록에 붙잡아 두는 데 쓴다.
   */
  onTagPopoverOpenChange?: (noteId: string, open: boolean) => void
}

export interface NoteCardHandle {
  focus: () => void
  /** 카드 아래 태그 팝오버를 연다 (t 단축키) */
  openTagPopover: () => void
}

export const NoteCard = memo(
  forwardRef<NoteCardHandle, Props>(
    (
      {
        note,
        isFocused,
        depth = 0,
        viewMode = 'active',
        onEscapeFromNormal,
        onReply,
        onTagPopoverOpenChange,
      },
      ref
    ) => {
      const editorRef = useRef<LexicalEditorHandle>(null)
      const pendingFocusRef = useRef(false)
      // 이번 편집 세션에서 본문이 실제로 바뀌었는지 — 팝오버를 열지 판단하는 근거
      const contentChangedRef = useRef(false)
      const latestContentRef = useRef(note.content)
      // `/`·`i`로만 켜지는 편집 상태. 포커스와는 다른 것이다 (BRU-53).
      const [isEditing, setIsEditing] = useState(false)
      const [showTagPopover, setShowTagPopover] = useState(false)
      const [showTemplatePopover, setShowTemplatePopover] = useState(false)
      // 템플릿을 넣은 뒤 에디터를 새 본문으로 다시 세우기 위한 세대 번호
      const [editorEpoch, setEditorEpoch] = useState(0)
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
      // 댓글은 노트가 아니라 별도 슬라이스에 있다 — 카드에는 개수만 온다 (BRU-63)
      const storedCommentCount = useNotesStore((s) => s.commentCountByNote[note.id] ?? 0)
      const commentsNoteId = useNotesStore((s) => s.commentsNoteId)
      const openComments = useNotesStore((s) => s.openComments)
      const closeComments = useNotesStore((s) => s.closeComments)

      // DB에서 잠금 상태이고 + 일시 해제되지 않은 경우에만 잠김
      const isLocked = note.isLocked && !temporarilyUnlockedNoteIds.has(note.id)

      // 상태는 둘뿐이다 — 한 줄(보기) / 펼침(편집).
      // 포커스는 펼침이 아니다: j/k/클릭으로 카드를 훑어도 한 줄 그대로 남고,
      // `/`·`i`로 편집에 들어왔을 때만 펼쳐진다 (BRU-53).
      const isOpen = isEditorOpen({ isFocused, isEditing })

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
      // 잠긴 노트는 댓글이 몇 개인지도 흘리지 않는다 — 첨부·링크 개수와 같은 규칙
      const commentCount = isLocked ? 0 : storedCommentCount

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

      // 팝오버 상태는 항상 이 함수로 바꾼다 — 피드가 Inbox 이탈을 유예하려면
      // 열림/닫힘을 하나도 놓치지 않고 알아야 한다 (BRU-50)
      const setTagPopoverOpen = useCallback(
        (open: boolean) => {
          setShowTagPopover(open)
          onTagPopoverOpenChange?.(note.id, open)
        },
        [note.id, onTagPopoverOpenChange]
      )

      // 카드가 통째로 사라질 때(삭제·보관 등) 피드에 남은 유예를 걷어낸다
      const tagPopoverOpenRef = useRef(false)
      tagPopoverOpenRef.current = showTagPopover
      useEffect(() => {
        return () => {
          if (tagPopoverOpenRef.current) onTagPopoverOpenChange?.(note.id, false)
        }
      }, [note.id, onTagPopoverOpenChange])

      useImperativeHandle(ref, () => ({
        focus: () => {
          // 편집 진입 = 펼침 + 캐럿. 카드가 아직 접혀 있으면 에디터가 없으므로
          // 펼쳐진 다음 잡도록 예약한다.
          setIsEditing(true)
          pendingFocusRef.current = true
          editorRef.current?.focus()
        },
        openTagPopover: () => {
          if (isLocked) return
          setTagPopoverOpen(true)
        },
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
          contentChangedRef.current = true
          latestContentRef.current = content
          updateNote(note.id, content)
        },
        [note.id, note.content, updateNote]
      )

      // 편집에서 빠져나오는 순간(Enter·Esc) 태그 팝오버를 연다.
      // 카드를 열어보기만 하고 나온 경우에는 열지 않는다 — 넘기는 데 벌이 없어야 한다.
      const handleEditorEscape = useCallback(() => {
        const shouldOpen = shouldOpenTagPopoverOnEditEnd({
          contentChanged: contentChangedRef.current,
          content: latestContentRef.current,
          isLocked,
        })
        contentChangedRef.current = false
        // 편집만 빠져나온다 — 포커스는 이 카드에 남는다 (한 줄로 되접힘)
        setIsEditing(false)
        if (shouldOpen) setTagPopoverOpen(true)
        onEscapeFromNormal()
      }, [isLocked, onEscapeFromNormal, setTagPopoverOpen])

      // 빈 노트에서 `/`를 치면 형식 목록이 뜬다. 내용이 있으면 그냥 글자다.
      const handleEditorKeyDown = useCallback(
        (e: React.KeyboardEvent) => {
          if (e.nativeEvent.isComposing) return
          if (
            !shouldOpenTemplateMenu({
              key: e.key,
              content: latestContentRef.current,
              isLocked,
            })
          ) {
            return
          }
          e.preventDefault()
          e.stopPropagation()
          setShowTemplatePopover(true)
        },
        [isLocked]
      )

      const handleInsertTemplate = useCallback(
        async (template: NoteTemplate) => {
          setShowTemplatePopover(false)
          contentChangedRef.current = true
          latestContentRef.current = template.content
          try {
            await updateNote(note.id, template.content)
          } catch (error) {
            console.error('Failed to insert template:', error)
            return
          }
          // 에디터는 initialContent를 마운트할 때 한 번만 읽는다 — 새로 세운다
          setEditorEpoch((epoch) => epoch + 1)
        },
        [note.id, updateNote]
      )

      // 다른 노트로 넘어가면(다음 노트 쓰기 시작 포함) 그냥 닫힌다.
      // 시간이 지나서 저절로 닫히는 길은 두지 않는다 — 놓치면 다시 부를 방법이 없어진다.
      useEffect(() => {
        if (!isFocused) {
          setIsEditing(false)
          setTagPopoverOpen(false)
          setShowTemplatePopover(false)
        }
      }, [isFocused, setTagPopoverOpen])

      // 템플릿을 넣고 나면 이어서 쓸 수 있게 에디터로 돌아간다
      useEffect(() => {
        if (editorEpoch === 0) return
        editorRef.current?.focus()
      }, [editorEpoch])

      // 바깥에서 본문이 바뀌어도(실시간 동기화 등) 최신값을 들고 있는다
      useEffect(() => {
        latestContentRef.current = note.content
      }, [note.content])

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
              {!isOpen && (attachmentCount > 0 || linkCount > 0 || commentCount > 0) && (
                <span className="note-line-counts">
                  {commentCount > 0 && (
                    <span className="note-line-count" title={`댓글 ${commentCount}개`}>
                      <Icon name="message-square" size={11} />
                      {commentCount}
                    </span>
                  )}
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
                          className="comment-btn"
                          onClick={() => openComments(note.id)}
                          title="댓글 (⇧C)"
                          aria-label="댓글"
                        >
                          <Icon name="message-square" />
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
                  <div className="note-editor" onKeyDown={handleEditorKeyDown}>
                    <LexicalEditor
                      key={`${note.id}:${editorEpoch}`}
                      ref={editorRef}
                      initialContent={note.content}
                      onChange={handleChange}
                      onEscape={handleEditorEscape}
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
          {showTagPopover && !isLocked && (
            // 카드 바깥에 둔다 — .note-card는 overflow:hidden이라 안에서는 잘린다
            <div className="note-card-popover-anchor">
              <TagPopover
                noteId={note.id}
                tags={note.tags}
                onClose={() => setTagPopoverOpen(false)}
              />
            </div>
          )}
          {showTemplatePopover && !isLocked && (
            <div className="note-card-popover-anchor">
              <TemplatePopover
                onInsert={handleInsertTemplate}
                onClose={() => {
                  setShowTemplatePopover(false)
                  editorRef.current?.focus()
                }}
              />
            </div>
          )}
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
          {commentsNoteId === note.id && !isLocked && (
            <CommentPanel noteId={note.id} onClose={closeComments} />
          )}
        </>
      )
    }
  )
)

NoteCard.displayName = 'NoteCard'
