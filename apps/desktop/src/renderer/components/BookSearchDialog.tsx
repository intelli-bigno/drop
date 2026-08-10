/// <reference path="../../preload/index.d.ts" />
import { useEffect, useRef, useState, useCallback, useMemo } from 'react'
import { useNotesStore } from '../stores/notes'
import { supabase } from '../lib/supabase'
import { Icon } from './Icon'
import type { AladinSearchResult, Book } from '@drop/shared'

type SearchItem =
  | { type: 'library'; book: Book }
  | { type: 'aladin'; book: AladinSearchResult }

const PAGE_SIZE = 20

export function BookSearchDialog() {
  const {
    isBookSearchOpen,
    bookSearchMode,
    linkTargetNoteId,
    closeBookSearch,
    books,
    librarySearchResults,
    aladinSearchResults,
    isSearchingBooks,
    searchBooks,
    addBookToLibrary,
    selectBook,
    linkNoteToBook,
  } = useNotesStore()

  const [query, setQuery] = useState('')
  const [selectedIndex, setSelectedIndex] = useState(0)
  const [isAdding, setIsAdding] = useState(false)
  const [displayLimit, setDisplayLimit] = useState(PAGE_SIZE)
  const inputRef = useRef<HTMLInputElement>(null)
  const listRef = useRef<HTMLDivElement>(null)
  const loadMoreRef = useRef<HTMLDivElement>(null)

  // 검색어 입력 디바운스
  const debounceRef = useRef<NodeJS.Timeout | null>(null)

  // 검색어가 없을 때 표시할 책 목록 (최신순, 무한 스크롤)
  const defaultBooks = useMemo(() => {
    // books는 이미 created_at desc로 정렬되어 있음
    return books.slice(0, displayLimit)
  }, [books, displayLimit])

  // 검색어 여부에 따라 표시할 내 서재 책 목록 결정
  const displayedLibraryBooks = query.trim() ? librarySearchResults : defaultBooks
  const hasMoreBooks = !query.trim() && books.length > displayLimit

  // 모든 결과를 하나의 배열로 합침 (키보드 네비게이션용)
  const allItems = useMemo<SearchItem[]>(() => {
    const items: SearchItem[] = []
    displayedLibraryBooks.forEach((book) => items.push({ type: 'library', book }))
    if (query.trim()) {
      aladinSearchResults.forEach((book) => items.push({ type: 'aladin', book }))
    }
    return items
  }, [displayedLibraryBooks, aladinSearchResults, query])

  const handleQueryChange = (value: string) => {
    setQuery(value)
    setSelectedIndex(0)

    if (debounceRef.current) {
      clearTimeout(debounceRef.current)
    }

    debounceRef.current = setTimeout(() => {
      searchBooks(value)
    }, 300)
  }

  // 다이얼로그가 열릴 때 포커스
  useEffect(() => {
    if (isBookSearchOpen) {
      setQuery('')
      setSelectedIndex(0)
      setIsAdding(false)
      setDisplayLimit(PAGE_SIZE)
      setTimeout(() => {
        inputRef.current?.focus()
      }, 0)
    }
  }, [isBookSearchOpen])

  // 무한 스크롤: IntersectionObserver로 더 보기
  useEffect(() => {
    if (!loadMoreRef.current || !isBookSearchOpen) return

    const observer = new IntersectionObserver(
      (entries) => {
        if (entries[0].isIntersecting && hasMoreBooks) {
          setDisplayLimit((prev) => prev + PAGE_SIZE)
        }
      },
      { threshold: 0.1 }
    )

    observer.observe(loadMoreRef.current)
    return () => observer.disconnect()
  }, [isBookSearchOpen, hasMoreBooks])

  // 선택된 항목이 보이도록 스크롤
  useEffect(() => {
    if (listRef.current && allItems.length > 0) {
      const allElements = listRef.current.querySelectorAll('.book-search-item')
      const selectedElement = allElements[selectedIndex] as HTMLElement
      selectedElement?.scrollIntoView({ block: 'nearest' })
    }
  }, [selectedIndex, allItems.length])

  // 내 서재 책 선택 시
  const handleSelectLibraryBook = useCallback(
    async (book: Book) => {
      if (bookSearchMode === 'link' && linkTargetNoteId) {
        // link 모드: 노트에 책 연결
        await linkNoteToBook(book.id, linkTargetNoteId)
        closeBookSearch()
      } else {
        // add 모드: 책 상세 페이지 열기
        selectBook(book.id)
        closeBookSearch()
      }
    },
    [bookSearchMode, linkTargetNoteId, linkNoteToBook, selectBook, closeBookSearch]
  )

  // 알라딘 책 선택 시 (라이브러리에 추가)
  const handleSelectAladinBook = useCallback(
    async (book: AladinSearchResult) => {
      if (isAdding) return

      setIsAdding(true)
      try {
        const addedBook = await addBookToLibrary(book.isbn13)
        if (addedBook) {
          closeBookSearch()
        }
      } finally {
        setIsAdding(false)
      }
    },
    [addBookToLibrary, closeBookSearch, isAdding]
  )

  // 통합 선택 핸들러
  const handleSelectItem = useCallback(
    (item: SearchItem) => {
      if (item.type === 'library') {
        handleSelectLibraryBook(item.book)
      } else {
        handleSelectAladinBook(item.book)
      }
    },
    [handleSelectLibraryBook, handleSelectAladinBook]
  )

  const handleKeyDown = (e: React.KeyboardEvent) => {
    switch (e.key) {
      case 'ArrowDown':
        e.preventDefault()
        setSelectedIndex((prev) => (prev < allItems.length - 1 ? prev + 1 : prev))
        break
      case 'ArrowUp':
        e.preventDefault()
        setSelectedIndex((prev) => (prev > 0 ? prev - 1 : prev))
        break
      case 'Enter':
        e.preventDefault()
        if (allItems[selectedIndex]) {
          handleSelectItem(allItems[selectedIndex])
        }
        break
      case 'Escape':
        e.preventDefault()
        closeBookSearch()
        break
    }
  }

  // 현재 선택된 인덱스가 어느 섹션에 있는지 계산
  const getItemIndex = (sectionType: 'library' | 'aladin', indexInSection: number): number => {
    if (sectionType === 'library') {
      return indexInSection
    }
    return displayedLibraryBooks.length + indexInSection
  }

  if (!isBookSearchOpen) return null

  const isLinkMode = bookSearchMode === 'link'
  const hasResults = displayedLibraryBooks.length > 0 || aladinSearchResults.length > 0
  const noResults = query.trim() && !isSearchingBooks && !hasResults

  // 모드에 따른 UI 텍스트
  const dialogTitle = isLinkMode ? '노트에 책 연결' : '책 검색'
  const placeholder = isLinkMode
    ? '연결할 책 검색 (내 서재에서)...'
    : '책 제목, 저자 또는 ISBN 입력...'
  const emptyMessage = isLinkMode
    ? '내 서재에 해당 책이 없습니다'
    : '검색 결과가 없습니다'

  return (
    <div className="book-search-overlay" onClick={closeBookSearch}>
      <div className="book-search-dialog" onClick={(e) => e.stopPropagation()}>
        <div className="book-search-header">
          <span className="book-search-title">{dialogTitle}</span>
          <button
            className="book-search-close"
            onClick={closeBookSearch}
            title="닫기"
            aria-label="닫기"
          >
            <Icon name="x" />
          </button>
        </div>

        <div className="book-search-input-wrapper">
          <span className="book-search-input-icon">
            <Icon name="search" size={14} />
          </span>
          <input
            ref={inputRef}
            type="text"
            className="book-search-input"
            placeholder={placeholder}
            value={query}
            onChange={(e) => handleQueryChange(e.target.value)}
            onKeyDown={handleKeyDown}
            disabled={isAdding}
          />
          {(isSearchingBooks || isAdding) && <span className="book-search-spinner" />}
        </div>

        <div className="book-search-results" ref={listRef}>
          {noResults ? (
            <div className="book-search-empty">{emptyMessage}</div>
          ) : !hasResults && !query.trim() && books.length === 0 ? (
            <div className="book-search-empty">서재가 비어있습니다</div>
          ) : (
            <>
              {/* 내 서재 섹션 */}
              {displayedLibraryBooks.length > 0 && (
                <div className="book-search-section">
                  <div className="book-search-section-title">
                    {isLinkMode ? '내 서재에서 선택' : query.trim() ? '내 서재' : '내 서재 전체'}
                  </div>
                  {displayedLibraryBooks.map((book, index) => {
                    const itemIndex = getItemIndex('library', index)
                    const coverUrl = book.coverStoragePath
                      ? supabase.storage.from('attachments').getPublicUrl(book.coverStoragePath)
                          .data.publicUrl
                      : book.coverUrl

                    return (
                      <div
                        key={book.id}
                        className={`book-search-item ${itemIndex === selectedIndex ? 'selected' : ''}`}
                        onClick={() => handleSelectLibraryBook(book)}
                        onMouseEnter={() => setSelectedIndex(itemIndex)}
                      >
                        <div className="book-search-item-cover">
                          {coverUrl ? (
                            <img src={coverUrl} alt={book.title} />
                          ) : (
                            <div className="book-search-item-cover-placeholder">
                              <Icon name="book" size={20} />
                            </div>
                          )}
                        </div>
                        <div className="book-search-item-info">
                          <p className="book-search-item-title">{book.title}</p>
                          <span className="book-search-item-meta">
                            {book.author}
                            {book.publisher && ` · ${book.publisher}`}
                          </span>
                          <span className="book-search-item-status">
                            {book.readingStatus === 'to_read' && (
                              <>
                                <Icon name="book-open" size={12} /> 읽을 예정
                              </>
                            )}
                            {book.readingStatus === 'reading' && (
                              <>
                                <Icon name="book" size={12} /> 읽는 중
                              </>
                            )}
                            {book.readingStatus === 'completed' && (
                              <>
                                <Icon name="check" size={12} /> 완독
                              </>
                            )}
                          </span>
                        </div>
                      </div>
                    )
                  })}
                  {/* 무한 스크롤 로더 */}
                  {hasMoreBooks && (
                    <div ref={loadMoreRef} className="book-search-load-more">
                      더 불러오는 중...
                    </div>
                  )}
                </div>
              )}

              {/* 알라딘 검색 섹션 (add 모드에서만, 검색어가 있을 때만) */}
              {!isLinkMode && query.trim() && aladinSearchResults.length > 0 && (
                <div className="book-search-section">
                  <div className="book-search-section-title">
                    {displayedLibraryBooks.length > 0 ? '새 책 추가' : '검색 결과'}
                  </div>
                  {aladinSearchResults.map((book, index) => {
                    const itemIndex = getItemIndex('aladin', index)

                    return (
                      <div
                        key={book.itemId}
                        className={`book-search-item ${itemIndex === selectedIndex ? 'selected' : ''}`}
                        onClick={() => handleSelectAladinBook(book)}
                        onMouseEnter={() => setSelectedIndex(itemIndex)}
                      >
                        <div className="book-search-item-cover">
                          {book.cover ? (
                            <img src={book.cover} alt={book.title} />
                          ) : (
                            <div className="book-search-item-cover-placeholder">
                              <Icon name="book" size={20} />
                            </div>
                          )}
                        </div>
                        <div className="book-search-item-info">
                          <p className="book-search-item-title">{book.title}</p>
                          <span className="book-search-item-meta">
                            {book.author}
                            {book.publisher && ` · ${book.publisher}`}
                            {book.pubDate && ` · ${book.pubDate.substring(0, 4)}`}
                          </span>
                        </div>
                      </div>
                    )
                  })}
                </div>
              )}
            </>
          )}
        </div>

        <div className="book-search-footer">
          <span className="book-search-hints">↑↓ 이동 · Enter 선택 · Esc 닫기</span>
        </div>
      </div>
    </div>
  )
}
