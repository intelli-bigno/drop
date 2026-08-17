import { useCallback, useLayoutEffect, useRef, useState } from 'react'
import type { Tag } from '@drop/shared'
import { useNotesStore } from '../stores/notes'
import { planTagOverflow, TAG_AREA_MAX_RATIO, type TagOverflowLayout } from '../lib/tag-overflow'
import { Icon } from './Icon'

interface ChipProps {
  name: string
  onSelect: () => void
  onRemove: (e: React.MouseEvent) => void
}

function TagChip({ name, onSelect, onRemove }: ChipProps) {
  return (
    <span className="tag-chip">
      <span className="tag-name" onClick={onSelect}>
        #{name}
      </span>
      <button className="tag-remove" onClick={onRemove} title="태그 제거" aria-label="태그 제거">
        <Icon name="x" size={10} />
      </button>
    </span>
  )
}

/** 접기 계산용 폭만 재는 그림자 줄 — visibility:hidden이라 보이지도, 잡히지도 않는다 */
function TagChipShadow({ name }: { name: string }) {
  return (
    <span className="tag-chip">
      <span className="tag-name">#{name}</span>
      <span className="tag-remove" />
    </span>
  )
}

interface Props {
  noteId: string
  tags: Tag[]
}

export function TagList({ noteId, tags }: Props) {
  const { removeTagFromNote, setFilterTag } = useNotesStore()
  const measureRef = useRef<HTMLDivElement>(null)
  const availableWidthRef = useRef(0)
  const [layout, setLayout] = useState<TagOverflowLayout>({
    visibleCount: tags.length,
    hiddenCount: 0,
  })

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

  // 칩 폭은 그림자 줄에서 잰다 — 접혀 있어도 폭을 알 수 있어야 창이 넓어질 때 다시 펼 수 있다
  const recompute = useCallback(() => {
    const measure = measureRef.current
    if (!measure) return
    const nodes = Array.from(measure.children) as HTMLElement[]
    if (nodes.length === 0) return
    const badgeWidth = nodes[nodes.length - 1].getBoundingClientRect().width
    const chipWidths = nodes.slice(0, -1).map((node) => node.getBoundingClientRect().width)
    const next = planTagOverflow(chipWidths, availableWidthRef.current, badgeWidth)
    setLayout((prev) =>
      prev.visibleCount === next.visibleCount && prev.hiddenCount === next.hiddenCount ? prev : next
    )
  }, [])

  // 가용 폭은 줄 전체 폭의 비율로 정한다. 태그 영역 자체를 재면
  // "접으면 좁아지고 좁아지면 더 접는" 순환에 빠진다.
  useLayoutEffect(() => {
    const row = measureRef.current?.closest('.note-line') ?? measureRef.current?.parentElement
    if (!row) return
    const observer = new ResizeObserver((entries) => {
      availableWidthRef.current = Math.floor(entries[0].contentRect.width * TAG_AREA_MAX_RATIO)
      recompute()
    })
    observer.observe(row)
    return () => observer.disconnect()
  }, [recompute])

  useLayoutEffect(() => {
    recompute()
  }, [tags, recompute])

  if (tags.length === 0) return null

  const visibleTags = tags.slice(0, layout.visibleCount)
  const hiddenTags = tags.slice(layout.visibleCount)

  return (
    <div className="tag-list">
      {visibleTags.map((tag) => (
        <TagChip
          key={tag.id}
          name={tag.name}
          onSelect={() => handleClick(tag.name)}
          onRemove={(e) => handleRemove(e, tag.id)}
        />
      ))}
      {hiddenTags.length > 0 && (
        <span
          className="tag-overflow"
          title={hiddenTags.map((tag) => `#${tag.name}`).join(' ')}
          aria-label={`태그 ${hiddenTags.length}개 더 있음`}
        >
          +{hiddenTags.length}
        </span>
      )}
      <div className="tag-list-measure" aria-hidden="true" ref={measureRef}>
        {tags.map((tag) => (
          <TagChipShadow key={tag.id} name={tag.name} />
        ))}
        <span className="tag-overflow">+{tags.length}</span>
      </div>
    </div>
  )
}
