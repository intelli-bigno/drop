import { useCallback } from 'react'
import type { Tag } from '@drop/shared'
import { useNotesStore } from '../stores/notes'
import { Icon } from './Icon'

interface Props {
  noteId: string
  tags: Tag[]
}

export function TagList({ noteId, tags }: Props) {
  const { removeTagFromNote, setFilterTag } = useNotesStore()

  const handleRemove = useCallback(
    (e: React.MouseEvent, tagId: string) => {
      e.stopPropagation()
      removeTagFromNote(noteId, tagId)
    },
    [noteId, removeTagFromNote]
  )

  const handleClick = useCallback(
    (tagName: string) => {
      setFilterTag(tagName)
    },
    [setFilterTag]
  )

  if (tags.length === 0) return null

  return (
    <div className="tag-list">
      {tags.map((tag) => (
        <span key={tag.id} className="tag-chip">
          <span className="tag-name" onClick={() => handleClick(tag.name)}>
            #{tag.name}
          </span>
          <button
            className="tag-remove"
            onClick={(e) => handleRemove(e, tag.id)}
            title="태그 제거"
            aria-label="태그 제거"
          >
            <Icon name="x" size={10} />
          </button>
        </span>
      ))}
    </div>
  )
}
