import { Icon, type IconName } from './Icon'
import { bulkActionsForViewMode, type BulkActionId, type BulkViewMode } from '../lib/bulk-actions'

interface Props {
  count: number
  viewMode: BulkViewMode
  onAction: (action: BulkActionId) => void
  onClear: () => void
}

const ACTION_LABELS: Record<BulkActionId, { label: string; icon: IconName; danger?: boolean }> = {
  tag: { label: '태그', icon: 'plus' },
  archive: { label: '보관', icon: 'archive' },
  unarchive: { label: '복원', icon: 'corner-up-left' },
  restore: { label: '복원', icon: 'corner-up-left' },
  trash: { label: '삭제', icon: 'trash', danger: true },
  deletePermanently: { label: '영구 삭제', icon: 'trash', danger: true },
}

/**
 * 선택 중일 때만 피드 아래에 붙는 일괄 액션 바 (BRU-80).
 * iOS의 SelectionActionBar(BRU-15)와 같은 액션 세트를 뷰 모드별로 보여준다.
 */
export function SelectionActionBar({ count, viewMode, onAction, onClear }: Props) {
  return (
    <div className="selection-action-bar" role="toolbar" aria-label="선택한 노트 일괄 작업">
      <span className="selection-count">{count}개 선택</span>
      <div className="selection-action-bar-spacer" />
      {bulkActionsForViewMode(viewMode).map((action) => {
        const { label, icon, danger } = ACTION_LABELS[action]
        return (
          <button
            key={action}
            className={`selection-action ${danger ? 'danger' : ''}`}
            onClick={() => onAction(action)}
          >
            <Icon name={icon} size={14} />
            <span>{label}</span>
          </button>
        )
      })}
      <button className="icon-btn" onClick={onClear} title="선택 해제 (Esc)" aria-label="선택 해제">
        <Icon name="x" size={12} />
      </button>
    </div>
  )
}
