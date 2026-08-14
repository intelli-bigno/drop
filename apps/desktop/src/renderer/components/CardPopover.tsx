import { useCallback, useEffect, useRef, useState, type KeyboardEvent } from 'react'
import { Icon } from './Icon'
import { moveSelection } from '../lib/tag-popover'

export interface CardPopoverItem {
  id: string
  label: string
  /** 이름 앞에 붙는 기호 (예: 태그의 #) */
  prefix?: string
  /** 오른쪽 보조 설명 */
  hint?: string
  /** 이미 선택된 항목 — 체크로 표시하고 다시 누르면 해제 */
  checked?: boolean
  /** 목록에 없는 것을 그 자리에서 만드는 행 */
  isCreate?: boolean
}

interface Props {
  /** 현재 입력값으로 보여줄 항목들 */
  buildItems: (query: string) => CardPopoverItem[]
  onSelect: (item: CardPopoverItem, query: string) => void
  onClose: () => void
  placeholder: string
  emptyLabel: string
  ariaLabel: string
  /** 고른 뒤에도 열어 둘지 — 태그는 연달아 여러 개를 달 수 있어야 한다 */
  keepOpenOnSelect?: boolean
}

/**
 * 카드 바로 아래에 붙는 목록 팝오버 (BRU-44).
 *
 * 배경을 막지 않는다 — 백드롭도 모달도 없다. 넘기는 데 벌이 없어야 하므로
 * Esc·바깥 클릭이면 그냥 닫히고, 시간이 지나 저절로 닫히는 일은 없다.
 */
export function CardPopover({
  buildItems,
  onSelect,
  onClose,
  placeholder,
  emptyLabel,
  ariaLabel,
  keepOpenOnSelect = false,
}: Props) {
  const [query, setQuery] = useState('')
  const [selectedIndex, setSelectedIndex] = useState(0)
  const inputRef = useRef<HTMLInputElement>(null)
  const rootRef = useRef<HTMLDivElement>(null)

  const items = buildItems(query)
  // 목록이 줄어들어 인덱스가 넘쳤을 때를 렌더 시점에 바로잡는다
  const activeIndex = moveSelection(selectedIndex, 0, items.length)

  // 열리자마자 바로 타이핑할 수 있어야 한다
  useEffect(() => {
    inputRef.current?.focus()
  }, [])

  // 바깥을 누르면 닫는다 (배경 동작은 그대로 살아 있다)
  useEffect(() => {
    const handlePointerDown = (e: MouseEvent) => {
      if (rootRef.current?.contains(e.target as Node)) return
      onClose()
    }
    document.addEventListener('mousedown', handlePointerDown)
    return () => document.removeEventListener('mousedown', handlePointerDown)
  }, [onClose])

  const handleSelect = useCallback(
    (item: CardPopoverItem) => {
      onSelect(item, query)
      if (keepOpenOnSelect) {
        setQuery('')
        setSelectedIndex(0)
        inputRef.current?.focus()
      } else {
        onClose()
      }
    },
    [onSelect, onClose, query, keepOpenOnSelect]
  )

  const handleKeyDown = useCallback(
    (e: KeyboardEvent) => {
      if (e.key === 'Escape') {
        e.preventDefault()
        e.stopPropagation()
        onClose()
        return
      }
      if (e.key === 'ArrowDown') {
        e.preventDefault()
        setSelectedIndex(moveSelection(activeIndex, 1, items.length))
        return
      }
      if (e.key === 'ArrowUp') {
        e.preventDefault()
        setSelectedIndex(moveSelection(activeIndex, -1, items.length))
        return
      }
      if (e.key === 'Enter') {
        e.preventDefault()
        e.stopPropagation()
        if (e.nativeEvent.isComposing) return
        const item = items[activeIndex]
        if (item) handleSelect(item)
      }
    },
    [activeIndex, items, handleSelect, onClose]
  )

  return (
    <div
      ref={rootRef}
      className="card-popover"
      role="dialog"
      aria-label={ariaLabel}
      onClick={(e) => e.stopPropagation()}
    >
      <input
        ref={inputRef}
        type="text"
        className="card-popover-input"
        placeholder={placeholder}
        value={query}
        aria-label={ariaLabel}
        onChange={(e) => {
          setQuery(e.target.value)
          setSelectedIndex(0)
        }}
        onKeyDown={handleKeyDown}
      />
      <div className="card-popover-list">
        {items.length === 0 && <div className="card-popover-empty">{emptyLabel}</div>}
        {items.map((item, index) => (
          <button
            key={item.id}
            type="button"
            className={[
              'card-popover-item',
              index === activeIndex && 'selected',
              item.isCreate && 'create',
            ]
              .filter(Boolean)
              .join(' ')}
            onMouseEnter={() => setSelectedIndex(index)}
            onClick={() => handleSelect(item)}
          >
            <span className="card-popover-item-icon" aria-hidden="true">
              {item.isCreate ? (
                <Icon name="plus" size={12} />
              ) : item.checked ? (
                <Icon name="check" size={12} />
              ) : item.prefix ? (
                item.prefix
              ) : null}
            </span>
            <span className="card-popover-item-label">{item.label}</span>
            {item.hint && <span className="card-popover-item-hint">{item.hint}</span>}
          </button>
        ))}
      </div>
      <div className="card-popover-help">
        <span>
          <kbd>↑</kbd>
          <kbd>↓</kbd> 이동
        </span>
        <span>
          <kbd>Enter</kbd> 선택
        </span>
        <span>
          <kbd>Esc</kbd> 넘기기
        </span>
      </div>
    </div>
  )
}
