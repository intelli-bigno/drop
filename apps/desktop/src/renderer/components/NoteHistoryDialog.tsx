import { useEffect, useRef } from 'react'
import { useNotesStore } from '../stores/notes'
import { summarizeRevision } from '@drop/shared'
import { formatRelativeTime } from '../lib/time-utils'
import { Icon } from './Icon'

interface Props {
  noteId: string
  onClose: () => void
}

/**
 * 노트 편집 히스토리. 기록은 DB 트리거가 남기고 여기서는 열람·복원만 한다.
 * 복원도 하나의 편집이라 복원 직전 내용이 다시 기록된다 — 되돌리기를 되돌릴 수 있다.
 */
export function NoteHistoryDialog({ noteId, onClose }: Props) {
  const closeRef = useRef<HTMLButtonElement>(null)
  const revisions = useNotesStore((s) => s.revisionsByNote[noteId])
  const isLoading = useNotesStore((s) => s.isRevisionsLoading)
  const restoreRevision = useNotesStore((s) => s.restoreRevision)

  useEffect(() => {
    closeRef.current?.focus()
  }, [])

  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === 'Escape') {
      e.stopPropagation()
      onClose()
    }
  }

  const handleRestore = async (content: string) => {
    await restoreRevision(noteId, content)
    onClose()
  }

  return (
    <div
      className="history-backdrop"
      onClick={onClose}
      onKeyDown={handleKeyDown}
      role="presentation"
    >
      <div
        className="history-dialog"
        onClick={(e) => e.stopPropagation()}
        role="dialog"
        aria-modal="true"
        aria-label="편집 기록"
      >
        <div className="history-header">
          <h3 className="history-title">편집 기록</h3>
          <button
            ref={closeRef}
            type="button"
            className="history-close"
            onClick={onClose}
            aria-label="닫기"
          >
            Esc
          </button>
        </div>

        {isLoading && !revisions && <p className="history-empty">불러오는 중…</p>}

        {!isLoading && revisions?.length === 0 && (
          <p className="history-empty">
            아직 편집 기록이 없다. 노트를 수정하면 수정 직전 내용이 여기 쌓인다.
          </p>
        )}

        {revisions && revisions.length > 0 && (
          <ul className="history-list">
            {revisions.map((revision) => (
              <li className="history-row" key={revision.id}>
                <div className="history-row-main">
                  <span className="history-time">{formatRelativeTime(revision.createdAt)}</span>
                  <p className="history-preview">{summarizeRevision(revision.content)}</p>
                </div>
                <button
                  type="button"
                  className="history-restore"
                  onClick={() => handleRestore(revision.content)}
                >
                  <Icon name="corner-up-left" size={13} />
                  되돌리기
                </button>
              </li>
            ))}
          </ul>
        )}

        <p className="history-footnote">노트당 최근 20개까지 보관된다.</p>
      </div>
    </div>
  )
}
