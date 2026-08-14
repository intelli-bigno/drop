import { useCallback } from 'react'
import { CardPopover, type CardPopoverItem } from './CardPopover'
import { NOTE_TEMPLATES, filterTemplates, type NoteTemplate } from '../lib/note-templates'

interface Props {
  onInsert: (template: NoteTemplate) => void
  onClose: () => void
}

/**
 * 빈 노트에서 `/`를 쳤을 때 뜨는 형식 목록 (BRU-44).
 * 태그 팝오버와 같은 CardPopover를 쓴다 — 새 화면이 아니다.
 */
export function TemplatePopover({ onInsert, onClose }: Props) {
  const buildItems = useCallback(
    (query: string): CardPopoverItem[] =>
      filterTemplates(query).map((template) => ({
        id: template.id,
        label: template.title,
        hint: template.hint,
      })),
    []
  )

  const handleSelect = useCallback(
    (item: CardPopoverItem) => {
      const template = NOTE_TEMPLATES.find((t) => t.id === item.id)
      if (template) onInsert(template)
    },
    [onInsert]
  )

  return (
    <CardPopover
      ariaLabel="템플릿 고르기"
      placeholder="템플릿 검색..."
      emptyLabel="맞는 템플릿이 없습니다"
      buildItems={buildItems}
      onSelect={handleSelect}
      onClose={onClose}
    />
  )
}
