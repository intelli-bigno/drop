import { useMemo } from 'react'
import { useNotesStore } from '../stores/notes'
import { countInboxNotes } from '../lib/note-filters'
import { Icon } from './Icon'

/**
 * Inbox — 아직 분류되지 않은(태그가 하나도 없는) 활성 노트만 보는 필터 (BRU-50).
 *
 * 숫자를 항상 띄운다. 0이어도 숨기지 않는다 — 태그를 붙일 때마다 줄어들다가
 * 0에 닿는 걸 보는 것이 이 기능의 전부다.
 */
export function InboxFilter() {
  const notes = useNotesStore((s) => s.notes)
  const inboxOnly = useNotesStore((s) => s.inboxOnly)
  const setInboxOnly = useNotesStore((s) => s.setInboxOnly)

  const count = useMemo(() => countInboxNotes(notes), [notes])

  return (
    <button
      className={`inbox-filter-btn ${inboxOnly ? 'active' : ''}`}
      onClick={() => setInboxOnly(!inboxOnly)}
      title={inboxOnly ? 'Inbox 필터 해제' : '아직 태그가 없는 노트만 보기'}
      aria-pressed={inboxOnly}
    >
      <span className="inbox-filter-icon">
        <Icon name="inbox" size={13} />
      </span>
      <span className="inbox-filter-label">Inbox</span>
      <span className="inbox-filter-count">{count}</span>
    </button>
  )
}
