import { useState, useCallback, useRef, useEffect, KeyboardEvent, useMemo } from 'react'
import { useNotesStore } from '../stores/notes'
import { formatRelativeTime } from '../lib/time-utils'
import { SEARCH_LIMIT, buildSnippet, searchNotes } from '../lib/note-search'
import { toSingleLinePreview } from '../lib/note-line'
import { rovingIndex } from '../lib/action-bar'
import { Icon } from './Icon'

interface Props {
  onClose: () => void
  onSelectNote: (noteId: string) => void
}

/** 검색어가 비었을 때 보여줄 최근 노트 수 — 목록이 화면을 넘기지 않을 만큼만 */
const RECENT_COUNT = 7

export function SearchDialog({ onClose, onSelectNote }: Props) {
  const { notes } = useNotesStore()
  const [inputValue, setInputValue] = useState('')
  const [selectedIndex, setSelectedIndex] = useState(0)
  const inputRef = useRef<HTMLInputElement>(null)
  const listRef = useRef<HTMLDivElement>(null)
  // 방향키로 옮긴 직후에는 마우스가 **가만히 있어도** 커서 밑으로 다른 줄이
  // 흘러 들어와 mouseenter가 터진다. 그러면 골라 둔 줄을 마우스가 도로 뺏는다.
  // 마우스가 실제로 움직이기 전까지는 hover를 선택으로 치지 않는다.
  const pointerMovedRef = useRef(false)

  const query = inputValue.trim()

  const { rows, total, isRecent } = useMemo(() => {
    if (!query) {
      return { rows: notes.slice(0, RECENT_COUNT), total: notes.length, isRecent: true }
    }
    const result = searchNotes(notes, query)
    return { rows: result.hits, total: result.total, isRecent: false }
  }, [notes, query])

  useEffect(() => {
    const selected = listRef.current?.querySelector('.search-dialog-item.selected')
    selected?.scrollIntoView({ block: 'nearest' })
  }, [selectedIndex])

  useEffect(() => {
    requestAnimationFrame(() => inputRef.current?.focus())
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

  const move = useCallback(
    (delta: number) => {
      pointerMovedRef.current = false
      setSelectedIndex((prev) => {
        const next = rovingIndex(prev, rows.length, delta)
        return next < 0 ? 0 : next
      })
    },
    [rows.length]
  )

  const handleKeyDown = useCallback(
    (e: KeyboardEvent) => {
      e.stopPropagation()

      // 목록을 감싸 돈다 — 끝에서 멈추면 스무 번째에서 첫 줄로 가려고
      // 스무 번을 거슬러 올라가야 한다 (액션 줄과 같은 규칙).
      if (e.key === 'ArrowDown') {
        e.preventDefault()
        move(1)
        return
      }

      if (e.key === 'ArrowUp') {
        e.preventDefault()
        move(-1)
        return
      }

      if (e.key === 'Enter') {
        e.preventDefault()
        const row = rows[selectedIndex]
        if (row) handleSelect(row.id)
      }
    },
    [rows, selectedIndex, handleSelect, move]
  )

  const handleBackdropClick = useCallback(
    (e: React.MouseEvent) => {
      if (e.target === e.currentTarget) onClose()
    },
    [onClose]
  )

  return (
    <div className="search-dialog-backdrop" onClick={handleBackdropClick}>
      <div
        className="search-dialog"
        role="dialog"
        aria-modal="true"
        aria-label="노트 검색"
        onMouseMove={() => {
          pointerMovedRef.current = true
        }}
      >
        <div className="search-dialog-header">
          <Icon name="search" size={16} className="search-dialog-icon" />
          <input
            ref={inputRef}
            type="text"
            className="search-dialog-input"
            placeholder="노트 검색 — 내용 · #태그 · 번호"
            value={inputValue}
            onChange={(e) => setInputValue(e.target.value)}
            onKeyDown={handleKeyDown}
            autoFocus
          />
          {/* 개수는 자른 뒤가 아니라 전부를 센다. 더 있으면 더 있다고 말한다 —
              스무 개만 그리면서 "20개"라고 적으면 그게 전부인 줄 안다. */}
          {!isRecent && (
            <span className="search-dialog-count">
              {total > SEARCH_LIMIT ? `${SEARCH_LIMIT} / ${total}` : `${total}`}
            </span>
          )}
        </div>

        <div ref={listRef} className="search-dialog-list">
          {isRecent && rows.length > 0 && <p className="search-dialog-section">최근</p>}

          {rows.map((note, index) => (
            <div
              key={note.id}
              className={`search-dialog-item ${index === selectedIndex ? 'selected' : ''}`}
              onClick={() => handleSelect(note.id)}
              onMouseEnter={() => {
                if (pointerMovedRef.current) setSelectedIndex(index)
              }}
            >
              <span className="search-dialog-preview">
                {isRecent ? (
                  toSingleLinePreview(note.content)
                ) : (
                  // 맞은 자리를 형광펜으로 (MASTER 규칙 8) — 글자를 액센트 색으로
                  // 물들이면 링크와 구별되지 않는다.
                  buildSnippet(note.content, query).map((segment, i) =>
                    segment.match ? (
                      <mark className="search-dialog-mark" key={i}>
                        {segment.text}
                      </mark>
                    ) : (
                      <span key={i}>{segment.text}</span>
                    )
                  )
                )}
              </span>
              <span className="search-dialog-meta">
                {note.priority > 0 && (
                  <span
                    className={`search-dialog-priority priority-${note.priority}`}
                    aria-label={`긴급도 ${note.priority}`}
                  />
                )}
                {note.tags.length > 0 && (
                  <span className="search-dialog-tags">
                    {note.tags
                      .slice(0, 2)
                      .map((t) => `#${t.name}`)
                      .join(' ')}
                  </span>
                )}
                <span className="search-dialog-time">{formatRelativeTime(note.createdAt)}</span>
              </span>
            </div>
          ))}

          {!isRecent && rows.length === 0 && (
            <p className="search-dialog-empty">
              <strong>{query}</strong>에 맞는 노트가 없다
            </p>
          )}
          {isRecent && rows.length === 0 && <p className="search-dialog-empty">아직 노트가 없다</p>}
        </div>

        <div className="search-dialog-help">
          <span>
            <kbd>↑</kbd>
            <kbd>↓</kbd> 이동
          </span>
          <span>
            <kbd>Enter</kbd> 열기
          </span>
          <span>
            <kbd>Esc</kbd> 닫기
          </span>
        </div>
      </div>
    </div>
  )
}
