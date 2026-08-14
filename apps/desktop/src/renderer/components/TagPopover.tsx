import { useCallback, useMemo } from 'react'
import type { Tag } from '@drop/shared'
import { useNotesStore } from '../stores/notes'
import { CardPopover, type CardPopoverItem } from './CardPopover'
import { rankTagSuggestions, shouldShowCreateOption, normalizeTagName } from '../lib/tag-popover'

interface Props {
  noteId: string
  /** 이 노트에 이미 붙어 있는 태그 */
  tags: Tag[]
  onClose: () => void
}

const CREATE_ITEM_ID = '__create__'

/**
 * 편집에서 빠져나온 카드 바로 아래에 뜨는 태그 팝오버 (BRU-44).
 *
 * 아무것도 안 쳤을 때는 최근·자주 쓴 태그 순, 치면 좁혀지고,
 * 목록에 없는 이름이면 그 자리에서 만든다. 이미 붙은 태그는 체크로 보이고
 * 다시 누르면 뗀다. 하나 달아도 닫지 않는다 — 노트당 두세 개를 다는 일이 흔하다.
 */
export function TagPopover({ noteId, tags, onClose }: Props) {
  const allTags = useNotesStore((s) => s.allTags)
  const notes = useNotesStore((s) => s.notes)
  const addTagToNote = useNotesStore((s) => s.addTagToNote)
  const removeTagFromNote = useNotesStore((s) => s.removeTagFromNote)

  // 태그별 사용 횟수 — 최근 사용 시각이 같을 때의 순서 기준
  const usageCounts = useMemo(() => {
    const counts: Record<string, number> = {}
    for (const note of notes) {
      for (const tag of note.tags) {
        counts[tag.id] = (counts[tag.id] ?? 0) + 1
      }
    }
    return counts
  }, [notes])

  const attachedTagNames = useMemo(() => tags.map((t) => t.name), [tags])

  const buildItems = useCallback(
    (query: string): CardPopoverItem[] => {
      const suggestions = rankTagSuggestions({
        allTags,
        attachedTagNames,
        usageCounts,
        query,
      })

      const items: CardPopoverItem[] = suggestions.map((s) => ({
        id: s.id,
        label: s.name,
        prefix: '#',
        checked: s.attached,
      }))

      if (shouldShowCreateOption({ allTags, query })) {
        items.push({
          id: CREATE_ITEM_ID,
          label: `"${query.trim()}" 태그 만들기`,
          isCreate: true,
        })
      }

      return items
    },
    [allTags, attachedTagNames, usageCounts]
  )

  const handleSelect = useCallback(
    (item: CardPopoverItem, query: string) => {
      if (item.isCreate) {
        addTagToNote(noteId, normalizeTagName(query))
        return
      }
      if (item.checked) {
        removeTagFromNote(noteId, item.id)
        return
      }
      addTagToNote(noteId, item.label)
    },
    [noteId, addTagToNote, removeTagFromNote]
  )

  return (
    <CardPopover
      ariaLabel="태그 달기"
      placeholder="태그 검색 또는 생성..."
      emptyLabel="태그가 없습니다 — 이름을 입력하면 새로 만듭니다"
      buildItems={buildItems}
      onSelect={handleSelect}
      onClose={onClose}
      keepOpenOnSelect
    />
  )
}
