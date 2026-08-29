// Space 미리보기 패널 (BRU-179).
//
// **모달이 아니다.** macOS Finder의 Quick Look과 같은 자리다 — 열린 채로 j/k가
// 뒤 목록을 계속 움직이고 패널 내용이 그 포커스를 따라온다. 그래서 여기에는
// 포커스 트랩도, 포커스를 가져오는 동작도 없다. 키보드는 계속 피드가 듣는다.
//
// 기존 다이얼로그 6종(ConfirmDialog·PinDialog·SearchDialog…)과 의도적으로 다른
// 패턴이다. 그것들을 그대로 따랐다면 Space→Esc→j→Space가 되어, 훑기를 고치려다
// 더 나쁜 훑기를 만들었을 것이다.
//
// 겹쳐 뜨되 목록을 밀지 않는다 — 이 이슈의 목적 자체가 "훑는 동안 레이아웃이
// 움직이지 않는 것"이라 패널이 피드 폭을 건드리면 안 된다.

import { useMemo } from 'react'
import { NoteViewer } from './NoteViewer'
import { AttachmentList } from './AttachmentList'
import { LinkPreviews } from './LinkPreviews'
import { Icon } from './Icon'
import { TagList } from './TagList'
import { useNotesStore } from '../stores/notes'
import { formatRelativeTime } from '../lib/time-utils'
import type { Note } from '@drop/shared'

interface Props {
  note: Note
  onClose: () => void
}

export function NotePreviewPanel({ note, onClose }: Props) {
  const project = useNotesStore((s) =>
    note.projectId ? (s.allProjects.find((p) => p.id === note.projectId) ?? null) : null
  )
  const commentCount = useNotesStore((s) => s.commentCountByNote[note.id] ?? 0)

  // 잠긴 노트의 본문은 미리보기에도 나오지 않는다 — 잠금은 화면을 가리는 것이 아니라
  // 내용을 감추는 것이다. 여기서 새는 경로를 만들면 잠금이 무의미해진다.
  const isLocked = useNotesStore(
    (s) => note.isLocked && !s.temporarilyUnlockedNoteIds.has(note.id)
  )

  // 행에서 뺀 정보가 도착하는 곳이다 (BRU-187).
  // 목록은 조용하게 두되, 하나를 들여다볼 때는 전부 보여야 한다.
  const meta = useMemo(() => {
    const parts: string[] = [`#${note.displayId}`, formatRelativeTime(note.updatedAt)]
    if (project) parts.push(project.name)
    if (note.priority > 0) parts.push(`긴급도 ${note.priority}`)
    if (commentCount > 0) parts.push(`댓글 ${commentCount}`)
    if (note.attachments.length > 0) parts.push(`첨부 ${note.attachments.length}`)
    return parts
  }, [note.displayId, note.updatedAt, note.priority, note.attachments.length, project, commentCount])

  return (
    // aria-live 없이 role="complementary" — 보조 정보 영역이라는 뜻이고,
    // 포커스는 여전히 피드에 있다.
    <aside className="note-preview" role="complementary" aria-label="노트 미리보기">
      <header className="note-preview-head">
        <div className="note-preview-meta">
          {meta.map((part) => (
            <span key={part}>{part}</span>
          ))}
        </div>
        <button
          className="note-preview-close"
          onClick={onClose}
          aria-label="미리보기 닫기"
          title="미리보기 닫기 (Space 또는 Esc)"
        >
          <Icon name="x" />
        </button>
      </header>

      <div className="note-preview-body">
        {isLocked ? (
          <p className="note-preview-locked">
            <Icon name="lock" />
            잠긴 노트입니다
          </p>
        ) : (
          <>
            {/* 태그도 행에서 뺐으므로 여기가 유일하게 이름이 보이는 자리다 */}
            {note.tags.length > 0 && (
              <div className="note-preview-tags">
                <TagList noteId={note.id} tags={note.tags} />
              </div>
            )}
            <NoteViewer content={note.content} />
            {note.attachments.length > 0 && <AttachmentList attachments={note.attachments} />}
            <LinkPreviews content={note.content} attachments={note.attachments} />
          </>
        )}
      </div>

      <footer className="note-preview-foot">
        <kbd>Space</kbd> 닫기 · <kbd>J</kbd> <kbd>K</kbd> 열어 둔 채 넘기기
      </footer>
    </aside>
  )
}
