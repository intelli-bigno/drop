import { useEffect, useRef, useState } from 'react'
import { useNotesStore } from '../stores/notes'
import { formatRelativeTime } from '../lib/time-utils'
import { canSubmitComment, commentDeleteMessage } from '../lib/note-comments'
import { ConfirmDialog } from './ConfirmDialog'
import { Icon } from './Icon'

interface Props {
  noteId: string
  onClose: () => void
}

/**
 * 노트 댓글 패널 (BRU-63). Shift+C 또는 카드의 댓글 버튼으로 열린다.
 *
 * - 댓글은 노트가 아니다 — 여기서만 보이고 피드·검색·Inbox에는 나타나지 않는다.
 * - 새 댓글은 낙관적으로 먼저 붙고, 실패하면 스토어가 걷어낸다.
 * - 삭제는 되돌릴 수 없으므로 ConfirmDialog을 거친다 (BRU-54 패턴 그대로).
 */
export function CommentPanel({ noteId, onClose }: Props) {
  const comments = useNotesStore((s) => s.commentsByNote[noteId])
  const isLoading = useNotesStore((s) => s.isCommentsLoading)
  const addComment = useNotesStore((s) => s.addComment)
  const updateComment = useNotesStore((s) => s.updateComment)
  const requestDeleteComment = useNotesStore((s) => s.requestDeleteComment)
  const cancelDeleteComment = useNotesStore((s) => s.cancelDeleteComment)
  const confirmDeleteComment = useNotesStore((s) => s.confirmDeleteComment)
  const pendingDeleteCommentId = useNotesStore((s) => s.pendingDeleteCommentId)

  const [draft, setDraft] = useState('')
  const [editingId, setEditingId] = useState<string | null>(null)
  const [editDraft, setEditDraft] = useState('')
  const inputRef = useRef<HTMLTextAreaElement>(null)

  useEffect(() => {
    inputRef.current?.focus()
  }, [])

  const pendingDeleteComment = comments?.find((c) => c.id === pendingDeleteCommentId)

  const handleSubmit = () => {
    if (!canSubmitComment(draft)) return
    addComment(noteId, draft)
    setDraft('')
  }

  const handleInputKeyDown = (e: React.KeyboardEvent<HTMLTextAreaElement>) => {
    if (e.nativeEvent.isComposing) return
    // 패널 안의 키는 패널 것이다 — 뒤 피드의 단축키로 새어 나가지 않는다.
    e.stopPropagation()
    if (e.key === 'Escape') {
      e.preventDefault()
      onClose()
      return
    }
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault()
      handleSubmit()
    }
  }

  const handleEditKeyDown = (e: React.KeyboardEvent<HTMLTextAreaElement>, commentId: string) => {
    if (e.nativeEvent.isComposing) return
    e.stopPropagation()
    if (e.key === 'Escape') {
      e.preventDefault()
      setEditingId(null)
      return
    }
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault()
      if (!canSubmitComment(editDraft)) return
      updateComment(noteId, commentId, editDraft)
      setEditingId(null)
    }
  }

  return (
    <div
      className="comment-backdrop"
      onClick={onClose}
      onKeyDown={(e) => {
        if (e.key === 'Escape') {
          e.stopPropagation()
          onClose()
        }
      }}
      role="presentation"
    >
      <div
        className="comment-panel"
        onClick={(e) => e.stopPropagation()}
        role="dialog"
        aria-modal="true"
        aria-label="댓글"
      >
        <div className="comment-header">
          <h3 className="comment-title">댓글</h3>
          <button type="button" className="comment-close" onClick={onClose} aria-label="닫기">
            Esc
          </button>
        </div>

        {isLoading && !comments && <p className="comment-empty">불러오는 중…</p>}

        {comments && comments.length === 0 && (
          <p className="comment-empty">아직 댓글이 없다. 아래에 첫 댓글을 남겨보자.</p>
        )}

        {comments && comments.length > 0 && (
          <ul className="comment-list">
            {comments.map((comment) => (
              <li
                className={`comment-row ${comment.isPending ? 'pending' : ''}`}
                key={comment.id}
                data-comment-id={comment.id}
              >
                <div className="comment-row-head">
                  <span className="comment-time">{formatRelativeTime(comment.createdAt)}</span>
                  <div className="comment-row-actions">
                    <button
                      type="button"
                      className="comment-edit"
                      onClick={() => {
                        setEditingId(comment.id)
                        setEditDraft(comment.body)
                      }}
                      aria-label="댓글 수정"
                      title="수정"
                    >
                      <Icon name="pencil" size={13} />
                    </button>
                    <button
                      type="button"
                      className="comment-delete"
                      onClick={() => requestDeleteComment(comment.id)}
                      aria-label="댓글 삭제"
                      title="삭제"
                    >
                      <Icon name="x" size={13} />
                    </button>
                  </div>
                </div>
                {editingId === comment.id ? (
                  <textarea
                    className="comment-edit-input"
                    value={editDraft}
                    autoFocus
                    onChange={(e) => setEditDraft(e.target.value)}
                    onKeyDown={(e) => handleEditKeyDown(e, comment.id)}
                  />
                ) : (
                  <p className="comment-body">{comment.body}</p>
                )}
              </li>
            ))}
          </ul>
        )}

        <div className="comment-compose">
          <textarea
            ref={inputRef}
            className="comment-input"
            placeholder="댓글 남기기 — Enter로 등록, Shift+Enter로 줄바꿈"
            value={draft}
            onChange={(e) => setDraft(e.target.value)}
            onKeyDown={handleInputKeyDown}
            aria-label="댓글 입력"
          />
          <button
            type="button"
            className="comment-submit"
            onClick={handleSubmit}
            disabled={!canSubmitComment(draft)}
          >
            등록
          </button>
        </div>
      </div>

      {pendingDeleteComment && (
        <ConfirmDialog
          title="댓글 삭제"
          message={commentDeleteMessage(pendingDeleteComment.body)}
          confirmLabel="삭제"
          danger
          onConfirm={() => confirmDeleteComment()}
          onCancel={cancelDeleteComment}
        />
      )}
    </div>
  )
}
