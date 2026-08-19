import { useCallback, useMemo } from 'react'
import type { Note } from '@drop/shared'
import { useNotesStore } from '../stores/notes'
import { CardPopover, type CardPopoverItem } from './CardPopover'
import { rankTagSuggestions, shouldShowCreateOption, normalizeTagName } from '../lib/tag-popover'
import { tagIdsOnEveryNote } from '../lib/bulk-actions'

interface Props {
  /** 선택된 노트들 — 태그를 한 번에 붙이고 뗀다 */
  notes: Note[]
  onClose: () => void
}

/**
 * 선택 집합에 태그를 한 번에 다는 팝오버 (BRU-80).
 *
 * 한 장짜리 TagPopover와 같은 목록·같은 순서를 쓴다. 다른 점은 "붙어 있음"의 뜻뿐이다 —
 * 선택한 노트 **전부**에 달린 태그만 체크로 보이고, 다시 누르면 전부에서 뗀다.
 * 일부에만 달린 태그는 체크되지 않고, 누르면 나머지에 마저 붙는다.
 */
export function BulkTagPopover({ notes, onClose }: Props) {
  const allTags = useNotesStore((s) => s.allTags)
  const allNotes = useNotesStore((s) => s.notes)
  const addTagToNote = useNotesStore((s) => s.addTagToNote)
  const removeTagFromNote = useNotesStore((s) => s.removeTagFromNote)

  const usageCounts = useMemo(() => {
    const counts: Record<string, number> = {}
    for (const note of allNotes) {
      for (const tag of note.tags) {
        counts[tag.id] = (counts[tag.id] ?? 0) + 1
      }
    }
    return counts
  }, [allNotes])

  const attachedTagNames = useMemo(() => {
    const sharedIds = new Set(tagIdsOnEveryNote(notes))
    return allTags.filter((tag) => sharedIds.has(tag.id)).map((tag) => tag.name)
  }, [notes, allTags])

  const buildItems = useCallback(
    (query: string): CardPopoverItem[] => {
      const items: CardPopoverItem[] = rankTagSuggestions({
        allTags,
        attachedTagNames,
        usageCounts,
        query,
      }).map((s) => ({
        id: s.id,
        label: s.name,
        prefix: '#',
        checked: s.attached,
      }))

      if (shouldShowCreateOption({ allTags, query })) {
        items.push({
          id: '__create__',
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
      for (const note of notes) {
        if (item.isCreate) {
          void addTagToNote(note.id, normalizeTagName(query))
        } else if (item.checked) {
          void removeTagFromNote(note.id, item.id)
        } else {
          void addTagToNote(note.id, item.label)
        }
      }
    },
    [notes, addTagToNote, removeTagFromNote]
  )

  return (
    <CardPopover
      ariaLabel={`선택한 노트 ${notes.length}개에 태그 달기`}
      placeholder="태그 검색 또는 생성..."
      emptyLabel="태그가 없습니다 — 이름을 입력하면 새로 만듭니다"
      buildItems={buildItems}
      onSelect={handleSelect}
      onClose={onClose}
      keepOpenOnSelect
    />
  )
}
