import { useMemo } from 'react'
import { useNotesStore } from '../stores/notes'
import { countInboxNotes, countOpenTodos } from '../lib/note-filters'
import { nextFeedScope } from '../lib/feed-scope'
import { Icon } from './Icon'

/**
 * 피드 범위 필터 (BRU-199) — 예전의 Inbox 버튼과 할일 버튼을 하나로 합친 것.
 *
 *   전체 → Inbox → 할일 → 남은 할일 → 전체
 *
 * 왜 합쳤나: BRU-181에서 "할일로 분류된 노트는 Inbox를 떠난다"로 Inbox 정의에
 * 타입 축이 들어간 뒤로 두 필터는 배타가 됐다. 배타인 값을 버튼 둘로 들고 있으면
 * 동시에 켤 수 있는 것처럼 보이는데 실제로 켜면 목록이 항상 빈다.
 *
 * **숫자는 둘 다, 항상 띄운다.** 현재 상태의 숫자만 보이면 할일을 보는 동안
 * Inbox 적체가 안 보인다 — "태그를 붙일 때마다 줄어들다가 0에 닿는 걸 보는 것이
 * 기능의 전부"라는 BRU-50의 의도가 거기서 깨진다. 미분류는 0이어도 숨기지 않는다.
 */
const LABELS = {
  inbox: 'Inbox',
  todo: '할일',
  open: '남은 할일',
} as const

const TITLES = {
  null: '아직 분류되지 않은 노트만 보기',
  inbox: '할일만 보기',
  todo: '아직 안 끝난 할일만 보기',
  open: '필터 해제',
} as const

export function ScopeFilter() {
  const notes = useNotesStore((s) => s.notes)
  const feedScope = useNotesStore((s) => s.feedScope)
  const setFeedScope = useNotesStore((s) => s.setFeedScope)

  const inboxCount = useMemo(() => countInboxNotes(notes), [notes])
  const openTodoCount = useMemo(() => countOpenTodos(notes), [notes])

  return (
    <button
      className={`scope-filter-btn ${feedScope ? 'active' : ''}`}
      onClick={() => setFeedScope(nextFeedScope(feedScope))}
      data-hint={TITLES[String(feedScope) as keyof typeof TITLES]}
      aria-pressed={feedScope !== null}
    >
      {/* 꺼짐 상태에는 라벨을 두지 않는다. '전체'라고 적으면 바로 옆 카테고리 필터의
          '전체'와 같은 말이 한 줄에 둘이 되어 무엇의 전체인지 알 수 없다 (실측 후 수정).
          숫자 옆 아이콘이 이미 무엇을 세는지 말해 준다. */}
      {feedScope && <span className="scope-filter-label">{LABELS[feedScope]}</span>}
      <span className="scope-filter-counts">
        <span
          className={`scope-filter-count ${feedScope === 'inbox' ? 'current' : ''}`}
          data-hint={`분류되지 않은 노트 ${inboxCount}건`}
        >
          <Icon name="inbox" size={12} />
          {inboxCount}
        </span>
        <span
          className={`scope-filter-count ${feedScope === 'todo' || feedScope === 'open' ? 'current' : ''}`}
          data-hint={`아직 안 끝난 할일 ${openTodoCount}건`}
        >
          <Icon name="list-todo" size={12} />
          {openTodoCount}
        </span>
      </span>
    </button>
  )
}
