import { useNotesStore } from '../stores/notes'
import { Icon, type IconName } from './Icon'

export function CategoryFilter() {
  const categoryFilter = useNotesStore((s) => s.categoryFilter)
  const setCategoryFilter = useNotesStore((s) => s.setCategoryFilter)

  const filters: Array<{
    key: 'link' | 'media' | 'files' | null
    label: string
    hint: string
    icon?: IconName
  }> = [
    { key: null, label: '전체', hint: '거르지 않고 모두 보기' },
    { key: 'link', label: '링크', hint: '링크가 들어 있는 노트만', icon: 'link' },
    { key: 'media', label: '미디어', hint: '사진·영상·소리가 붙은 노트만', icon: 'image' },
    { key: 'files', label: '파일', hint: '파일이 붙은 노트만', icon: 'paperclip' },
  ]

  return (
    <div className="category-filter">
      {filters.map((f) => (
        <button
          key={f.key ?? 'all'}
          className={`category-filter-btn ${categoryFilter === f.key ? 'active' : ''}`}
          onClick={() => setCategoryFilter(f.key)}
          data-hint={f.hint}
        >
          {f.icon && (
            <span className="category-filter-icon">
              <Icon name={f.icon} size={12} />
            </span>
          )}
          {f.label}
        </button>
      ))}
    </div>
  )
}
