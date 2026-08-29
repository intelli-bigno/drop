import { useState, useCallback, useRef, useEffect, KeyboardEvent } from 'react'
import { useNotesStore } from '../stores/notes'
import { Icon } from './Icon'

interface Props {
  onClose: () => void
}

export function TagManagementDialog({ onClose }: Props) {
  const { allTags, notes, updateTag, deleteTag } = useNotesStore()
  const [searchQuery, setSearchQuery] = useState('')
  const [editingTagId, setEditingTagId] = useState<string | null>(null)
  const [editingValue, setEditingValue] = useState('')
  const [deleteConfirmId, setDeleteConfirmId] = useState<string | null>(null)
  const inputRef = useRef<HTMLInputElement>(null)
  const editInputRef = useRef<HTMLInputElement>(null)

  // Calculate note count for each tag
  const getTagNoteCount = useCallback(
    (tagId: string) => {
      return notes.filter((note) => note.tags.some((t) => t.id === tagId)).length
    },
    [notes]
  )

  // Filter tags by search query
  const filteredTags = searchQuery
    ? allTags.filter((tag) => tag.name.toLowerCase().includes(searchQuery.toLowerCase()))
    : allTags

  // Auto-focus search input
  useEffect(() => {
    inputRef.current?.focus()
  }, [])

  // Focus edit input when editing starts
  useEffect(() => {
    if (editingTagId) {
      editInputRef.current?.focus()
      editInputRef.current?.select()
    }
  }, [editingTagId])

  const handleBackdropClick = useCallback(
    (e: React.MouseEvent) => {
      if (e.target === e.currentTarget) {
        onClose()
      }
    },
    [onClose]
  )

  const handleKeyDown = useCallback(
    (e: KeyboardEvent) => {
      if (e.key === 'Escape') {
        e.preventDefault()
        if (editingTagId) {
          setEditingTagId(null)
          setEditingValue('')
        } else if (deleteConfirmId) {
          setDeleteConfirmId(null)
        } else {
          onClose()
        }
      }
    },
    [onClose, editingTagId, deleteConfirmId]
  )

  const startEditing = useCallback((tagId: string, currentName: string) => {
    setEditingTagId(tagId)
    setEditingValue(currentName)
    setDeleteConfirmId(null)
  }, [])

  const handleEditKeyDown = useCallback(
    async (e: KeyboardEvent, tagId: string) => {
      if (e.key === 'Enter') {
        e.preventDefault()
        const trimmed = editingValue.trim()
        if (trimmed && trimmed !== allTags.find((t) => t.id === tagId)?.name) {
          await updateTag(tagId, trimmed)
        }
        setEditingTagId(null)
        setEditingValue('')
      } else if (e.key === 'Escape') {
        e.preventDefault()
        setEditingTagId(null)
        setEditingValue('')
      }
    },
    [editingValue, updateTag, allTags]
  )

  const handleEditBlur = useCallback(
    async (tagId: string) => {
      const trimmed = editingValue.trim()
      if (trimmed && trimmed !== allTags.find((t) => t.id === tagId)?.name) {
        await updateTag(tagId, trimmed)
      }
      setEditingTagId(null)
      setEditingValue('')
    },
    [editingValue, updateTag, allTags]
  )

  const handleDeleteClick = useCallback((tagId: string) => {
    setDeleteConfirmId(tagId)
    setEditingTagId(null)
  }, [])

  const handleConfirmDelete = useCallback(
    async (tagId: string) => {
      await deleteTag(tagId)
      setDeleteConfirmId(null)
    },
    [deleteTag]
  )

  const handleCancelDelete = useCallback(() => {
    setDeleteConfirmId(null)
  }, [])

  return (
    <div className="tag-management-backdrop" onClick={handleBackdropClick}>
      <div className="tag-management-dialog" onKeyDown={handleKeyDown}>
        <div className="tag-management-header">
          <h2 className="tag-management-title">태그 관리</h2>
          <button className="tag-management-close" onClick={onClose} aria-label="닫기">
            <Icon name="x" size={20} />
          </button>
        </div>

        <div className="tag-management-search">
          <Icon name="search" size={16} className="tag-management-search-icon" />
          <input
            ref={inputRef}
            type="text"
            className="tag-management-search-input"
            placeholder="태그 검색..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            onKeyDown={handleKeyDown}
          />
        </div>

        <div className="tag-management-list">
          {filteredTags.length === 0 ? (
            <div className="tag-management-empty">
              {searchQuery ? '검색 결과가 없습니다' : '태그가 없습니다'}
            </div>
          ) : (
            filteredTags.map((tag) => {
              const noteCount = getTagNoteCount(tag.id)
              const isEditing = editingTagId === tag.id
              const isDeleting = deleteConfirmId === tag.id

              return (
                <div key={tag.id} className="tag-management-item">
                  {isDeleting ? (
                    <div className="tag-management-delete-confirm">
                      <span className="tag-management-delete-message">
                        "{tag.name}" 태그를 삭제하시겠습니까?
                      </span>
                      <div className="tag-management-delete-actions">
                        <button
                          className="tag-management-delete-cancel"
                          onClick={handleCancelDelete}
                        >
                          취소
                        </button>
                        <button
                          className="tag-management-delete-confirm-btn"
                          onClick={() => handleConfirmDelete(tag.id)}
                        >
                          삭제
                        </button>
                      </div>
                    </div>
                  ) : isEditing ? (
                    <div className="tag-management-edit-row">
                      <span className="tag-management-hash">#</span>
                      <input
                        ref={editInputRef}
                        type="text"
                        className="tag-management-edit-input"
                        value={editingValue}
                        onChange={(e) => setEditingValue(e.target.value)}
                        onKeyDown={(e) => handleEditKeyDown(e, tag.id)}
                        onBlur={() => handleEditBlur(tag.id)}
                      />
                    </div>
                  ) : (
                    <>
                      <div
                        className="tag-management-info"
                        onClick={() => startEditing(tag.id, tag.name)}
                      >
                        <span className="tag-management-hash">#</span>
                        <span className="tag-management-name">{tag.name}</span>
                        <span className="tag-management-count">{noteCount}</span>
                      </div>
                      <button
                        className="tag-management-delete-btn"
                        onClick={() => handleDeleteClick(tag.id)}
                        aria-label="태그 삭제"
                      >
                        <Icon name="trash" size={16} />
                      </button>
                    </>
                  )}
                </div>
              )
            })
          )}
        </div>

        <div className="tag-management-footer">
          <span className="tag-management-total">
            총 {allTags.length}개의 태그
          </span>
        </div>
      </div>
    </div>
  )
}
