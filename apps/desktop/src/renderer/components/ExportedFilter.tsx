import { useMemo } from 'react'
import { useNotesStore } from '../stores/notes'
import { isExportedNote } from '../lib/note-filters'
import { Icon } from './Icon'

/**
 * 반출된 노트 보기 (BRU-45).
 *
 * 반출된 노트는 기본 목록에서 빠진다 — 처리가 끝난 것이 계속 보이면 같은 노트를
 * 두 번 처리하기 때문이다. 그렇다고 영영 못 보게 두면 잘못 반출한 노트를
 * 되돌릴 길이 없어서, 이 토글로 다시 꺼내 본다.
 *
 * 반출된 노트가 하나도 없으면 버튼 자체를 띄우지 않는다 — 헤더에 늘 켜 둘 만큼
 * 자주 쓰는 것이 아니다. (Inbox 카운트는 0이어도 띄우는 것과 반대 판단이다:
 * 저쪽은 0에 닿는 걸 보는 것이 기능의 전부다.)
 */
export function ExportedFilter() {
  const notes = useNotesStore((s) => s.notes)
  const showExported = useNotesStore((s) => s.showExported)
  const setShowExported = useNotesStore((s) => s.setShowExported)

  const count = useMemo(() => notes.filter(isExportedNote).length, [notes])

  if (count === 0) return null

  return (
    <button
      className={`count-filter-btn ${showExported ? 'active' : ''}`}
      onClick={() => setShowExported(!showExported)}
      title={showExported ? '반출된 노트 숨기기' : 'Linear로 반출된 노트도 보기'}
      aria-pressed={showExported}
    >
      <span className="count-filter-icon">
        <Icon name="link" size={13} />
      </span>
      <span className="count-filter-label">반출됨</span>
      <span className="count-filter-count">{count}</span>
    </button>
  )
}
