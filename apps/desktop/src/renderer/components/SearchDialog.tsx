import { useState, useCallback, useRef, useEffect, KeyboardEvent, useMemo } from 'react'
import { useNotesStore } from '../stores/notes'
import { formatRelativeTime } from '../lib/time-utils'
import { Icon } from './Icon'

interface Props {
  onClose: () => void
  onSelectNote: (noteId: string) => void
}

export function SearchDialog({ onClose, onSelectNote }: Props) {
  const { notes } = useNotesStore()
  const [inputValue, setInputValue] = useState('')
  const [selectedIndex, setSelectedIndex] = useState(0)
  const inputRef = useRef<HTMLInputElement>(null)
  const listRef = useRef<HTMLDivElement>(null)

  const results = useMemo(() => {
    if (!inputValue.trim()) return []
    const query = inputValue.toLowerCase()
    return notes.filter((note) => note.content.toLowerCase().includes(query)).slice(0, 20)
  }, [notes, inputValue])

  useEffect(() => {
    if (listRef.current) {
      const selectedEl = listRef.current.querySelector('.search-dialog-item.selected')
      selectedEl?.scrollIntoView({ block: 'nearest' })
    }
  }, [selectedIndex])

  useEffect(() => {
    requestAnimationFrame(() => {
      inputRef.current?.focus()
    })
  }, [])

  useEffect(() => {
    const handleGlobalKeyDown = (e: globalThis.KeyboardEvent) => {
      if (e.key === 'Escape') {
        e.preventDefault()
        e.stopPropagation()
        onClose()
      }
    }

    window.addEventListener('keydown', handleGlobalKeyDown, true)
    return () => window.removeEventListener('keydown', handleGlobalKeyDown, true)
  }, [onClose])

  useEffect(() => {
    setSelectedIndex(0)
  }, [inputValue])

  const handleSelect = useCallback(
    (noteId: string) => {
      onSelectNote(noteId)
      onClose()
    },
    [onSelectNote, onClose]
  )

  const handleKeyDown = useCallback(
    (e: KeyboardEvent) => {
      e.stopPropagation()

      if (e.key === 'ArrowDown') {
        e.preventDefault()
        setSelectedIndex((prev) => Math.min(prev + 1, results.length - 1))
        return
      }

      if (e.key === 'ArrowUp') {
        e.preventDefault()
        setSelectedIndex((prev) => Math.max(prev - 1, 0))
        return
      }

      if (e.key === 'Enter') {
        e.preventDefault()
        if (results[selectedIndex]) {
          handleSelect(results[selectedIndex].id)
        }
      }
    },
    [results, selectedIndex, handleSelect]
  )

  const handleBackdropClick = useCallback(
    (e: React.MouseEvent) => {
      if (e.target === e.currentTarget) {
        onClose()
      }
    },
    [onClose]
  )

  const getPreview = (content: string, maxLength = 80) => {
    const firstLine = content.split('\n')[0]
    if (firstLine.length <= maxLength) return firstLine
    return firstLine.slice(0, maxLength) + '...'
  }

  const getPriorityIndicator = (priority: number) => {
    switch (priority) {
      case 1:
        return <span className="search-dialog-priority priority-low">!</span>
      case 2:
        return <span className="search-dialog-priority priority-medium">!!</span>
      case 3:
        return <span className="search-dialog-priority priority-high">!!!</span>
      default:
        return null
    }
  }

  return (
    <div className="search-dialog-backdrop" onClick={handleBackdropClick}>
      <div className="search-dialog">
        <div className="search-dialog-header">
          <span className="search-dialog-icon">
            <Icon name="search" />
          </span>
          <input
            ref={inputRef}
            type="text"
            className="search-dialog-input"
            placeholder="노트 검색..."
            value={inputValue}
            onChange={(e) => setInputValue(e.target.value)}
            onKeyDown={handleKeyDown}
            autoFocus
          />
          {inputValue && <span className="search-dialog-count">{results.length}개</span>}
        </div>
        <div ref={listRef} className="search-dialog-list">
          {results.map((note, index) => (
            <div
              key={note.id}
              className={`search-dialog-item ${index === selectedIndex ? 'selected' : ''}`}
              onClick={() => handleSelect(note.id)}
              onMouseEnter={() => setSelectedIndex(index)}
            >
              <div className="search-dialog-item-content">
                <span className="search-dialog-preview">{getPreview(note.content)}</span>
                {note.tags.length > 0 && (
                  <span className="search-dialog-tags">
                    {note.tags
                      .slice(0, 3)
                      .map((t) => `#${t.name}`)
                      .join(' ')}
                  </span>
                )}
              </div>
              <div className="search-dialog-item-meta">
                {getPriorityIndicator(note.priority)}
                <span className="search-dialog-time">{formatRelativeTime(note.createdAt)}</span>
              </div>
            </div>
          ))}
          {inputValue && results.length === 0 && (
            <div className="search-dialog-empty">검색 결과가 없습니다</div>
          )}
          {!inputValue && <div className="search-dialog-hint">검색어를 입력하세요</div>}
        </div>
        <div className="search-dialog-footer">
          <span className="search-dialog-shortcut">↑↓ 이동</span>
          <span className="search-dialog-shortcut">Enter 선택</span>
          <span className="search-dialog-shortcut">Esc 닫기</span>
        </div>
      </div>
    </div>
  )
}
