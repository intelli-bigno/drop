import { useNotesStore } from '../stores/notes'
import { Icon, type IconName } from './Icon'

export function CategoryFilter() {
  const categoryFilter = useNotesStore((s) => s.categoryFilter)
  const setCategoryFilter = useNotesStore((s) => s.setCategoryFilter)

  const filters: Array<{ key: 'link' | 'media' | 'files' | null; label: string; icon?: IconName }> =
    [
      { key: null, label: '전체' },
      { key: 'link', label: '링크', icon: 'link' },
      { key: 'media', label: '미디어', icon: 'image' },
      { key: 'files', label: '파일', icon: 'paperclip' },
    ]

  return (
    <div className="category-filter">
      {filters.map((f) => (
        <button
          key={f.key ?? 'all'}
          className={`category-filter-btn ${categoryFilter === f.key ? 'active' : ''}`}
          onClick={() => setCategoryFilter(f.key)}
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
