import { useRef, useState, useCallback, useEffect, useMemo } from 'react'
import type { Note } from '@drop/shared'
import { useNotesStore } from '../stores/notes'
import { useProfileStore } from '../stores/profile'
import { NoteCard, NoteCardHandle } from './NoteCard'
import { TagManagementDialog } from './TagManagementDialog'
import { CategoryFilter } from './CategoryFilter'
import { InboxFilter } from './InboxFilter'
import { ExportedFilter } from './ExportedFilter'
import { ViewModeSelector } from './ViewModeSelector'
import { SearchDialog } from './SearchDialog'
import { PinDialog, type PinDialogMode } from './PinDialog'
import { ConfirmDialog } from './ConfirmDialog'
import { Icon } from './Icon'
import { isCreateNoteShortcut, isSearchShortcut } from '../shortcuts/noteGlobal'
import { resolveNoteFeedShortcut } from '../shortcuts/noteFeed'
import { isOpenTagListShortcut, isOpenTagManagementShortcut } from '../shortcuts/tagList'
import { isToggleLockShortcut } from '../shortcuts/noteLock'
import { isOpenCommentsShortcut } from '../shortcuts/noteComments'
import { isDeleteShortcut, isArchiveShortcut, isRestoreShortcut } from '../shortcuts/noteTrash'
import { isTextInputTarget, getClosestNoteId } from '../lib/dom-utils'
import { extractInstagramUrls } from '../lib/instagram-url-utils'
import { buildDeleteConfirmMessage } from '../lib/delete-confirm'
import { computeFeedScrollTop } from '../lib/feed-scroll'
import { applyNoteFilters } from '../lib/note-filters'
import { buildNoteRows } from '../lib/note-hierarchy'

// 피드 상단에서 헤더에 가려지는 높이. 이만큼 여유를 두고 카드를 맞춘다.
const FEED_TOP_INSET = 60
import { extractYouTubeUrls } from '../lib/youtube-url-utils'
import { useDragAndDrop } from '../hooks'

// 큰 텍스트 임계값 (둘 다 충족해야 텍스트 첨부파일로 처리)
const LARGE_TEXT_THRESHOLD_LINES = 20
const LARGE_TEXT_THRESHOLD_CHARS = 1000

export function NoteFeed() {
  const {
    notes,
    isLoading,
    createNote,
    deleteNote,
    requestDeleteNote,
    pendingDeleteNoteId,
    cancelDeleteNote,
    confirmDeleteNote,
    addAttachment,
    createNoteWithInstagram,
    createNoteWithYouTube,
    filterTag,
    setFilterTag,
    categoryFilter,
    inboxOnly,
    setInboxOnly,
    showExported,
    lockNote,
    temporarilyUnlockNote,
    temporarilyUnlockAll,
    hasLockedNotes,
    viewMode,
    trashedNotes,
    archivedNotes,
    restoreNote,
    emptyTrash,
    archiveNote,
    unarchiveNote,
    updateNotePriority,
    togglePinNote,
    selectedNoteId,
    selectNote,
  } = useNotesStore()
  const [focusedIndex, setFocusedIndex] = useState<number | null>(null)
  const [showTagManagement, setShowTagManagement] = useState(false)
  const [pinDialogNoteId, setPinDialogNoteId] = useState<string | null>(null)
  const [pinDialogMode, setPinDialogMode] = useState<PinDialogMode>('setup')
  const [showUnlockAllDialog, setShowUnlockAllDialog] = useState(false)
  const [showSearchDialog, setShowSearchDialog] = useState(false)
  const [showEmptyTrashConfirm, setShowEmptyTrashConfirm] = useState(false)
  // 지금 팝오버가 열려 있는 노트 (필터에서 목록 이탈을 유예하는 데 쓴다)
  const [popoverNoteId, setPopoverNoteId] = useState<string | null>(null)
  const hasPin = useProfileStore((s) => s.hasPin)
  const cardRefs = useRef<Map<string, NoteCardHandle>>(new Map())
  const feedRef = useRef<HTMLDivElement>(null)

  // 이벤트 핸들러용 ref (의존성 분리) - 나중에 업데이트됨
  const focusedIndexRef = useRef<number | null>(focusedIndex)
  const orderedNotesRef = useRef<Array<{ note: Note; depth: number }>>([])
  const deleteNoteRef = useRef<(id: string) => void>(deleteNote)
  const requestDeleteNoteRef = useRef<(id: string) => void>(requestDeleteNote)
  const handleReplyRef = useRef<(parentId: string) => Promise<void>>(() => Promise.resolve())
  const handleCreateSiblingRef = useRef<(parentId: string | null) => Promise<void>>(() =>
    Promise.resolve()
  )
  const updateNotePriorityRef =
    useRef<(id: string, priority: number) => Promise<void>>(updateNotePriority)
  const togglePinNoteRef = useRef<(id: string) => Promise<void>>(togglePinNote)

  // 새 노트 생성 + 첨부물 추가 헬퍼 (useDragAndDrop에서 사용하기 위해 먼저 정의)
  const createNoteWithFile = useCallback(
    async (file: File) => {
      const note = await createNote()
      await addAttachment(note.id, file)
      setTimeout(() => {
        cardRefs.current.get(note.id)?.focus()
      }, 50)
    },
    [createNote, addAttachment]
  )

  const { isDragOver, handleDragOver, handleDragLeave, handleDrop } = useDragAndDrop({
    onDrop: async (files) => {
      for (const file of files) {
        await createNoteWithFile(file)
      }
    },
  })

  // 뷰 모드에 따른 노트 목록 선택
  const baseNotes = useMemo(() => {
    if (viewMode === 'trash') return trashedNotes
    if (viewMode === 'archived') return archivedNotes
    return notes
  }, [viewMode, notes, trashedNotes, archivedNotes])

  // 삭제 확인 대상 — 어느 뷰에서 눌렸든 현재 목록에서 찾는다
  const pendingDeleteNote = useMemo(
    () => (pendingDeleteNoteId ? baseNotes.find((n) => n.id === pendingDeleteNoteId) : undefined),
    [pendingDeleteNoteId, baseNotes]
  )

  // Inbox에서 태그 팝오버가 열려 있는 노트. 태그를 다는 순간 목록에서 빠지면
  // 팝오버가 허공에 뜨고 두 번째 태그를 달 길이 사라진다 — 닫힐 때까지 자리를 지킨다.
  const retainedNoteIds = useMemo(
    () => (popoverNoteId ? new Set([popoverNoteId]) : undefined),
    [popoverNoteId]
  )

  const filteredNotes = useMemo(() => {
    if (viewMode !== 'active') return baseNotes
    return applyNoteFilters(baseNotes, {
      filterTag,
      categoryFilter,
      inboxOnly,
      showExported,
      retainedNoteIds,
    })
  }, [viewMode, baseNotes, filterTag, categoryFilter, inboxOnly, showExported, retainedNoteIds])

  // 부모-자식 묶음 (BRU-70). 로직은 lib/note-hierarchy.ts에 있다 — 화면 안에 두면
  // 테스트할 수 없고, 실제로 그래서 "부모가 필터에서 빠지면 답글이 사라지는" 버그를
  // 오래 못 잡았다. 맥락 후보로 baseNotes를 넘겨 부모를 끌어올 수 있게 한다.
  const flatNotes = useMemo(
    () => buildNoteRows(filteredNotes, baseNotes),
    [filteredNotes, baseNotes]
  )

  // 답글 생성
  const handleReply = useCallback(
    async (parentId: string) => {
      const note = await createNote('', parentId)
      setTimeout(() => {
        cardRefs.current.get(note.id)?.focus()
      }, 50)
    },
    [createNote]
  )

  // 같은 레벨에 노트 생성 (형제 노트)
  const handleCreateSibling = useCallback(
    async (parentId: string | null) => {
      const note = await createNote('', parentId ?? undefined)
      setTimeout(() => {
        cardRefs.current.get(note.id)?.focus()
      }, 50)
    },
    [createNote]
  )

  // refs 업데이트 (이벤트 핸들러에서 최신 값 참조용)
  useEffect(() => {
    focusedIndexRef.current = focusedIndex
  }, [focusedIndex])

  useEffect(() => {
    deleteNoteRef.current = deleteNote
  }, [deleteNote])

  useEffect(() => {
    requestDeleteNoteRef.current = requestDeleteNote
  }, [requestDeleteNote])

  useEffect(() => {
    handleReplyRef.current = handleReply
  }, [handleReply])

  useEffect(() => {
    handleCreateSiblingRef.current = handleCreateSibling
  }, [handleCreateSibling])

  useEffect(() => {
    updateNotePriorityRef.current = updateNotePriority
  }, [updateNotePriority])

  useEffect(() => {
    togglePinNoteRef.current = togglePinNote
  }, [togglePinNote])

  // 카드가 팝오버를 열고 닫을 때 알려온다 (BRU-50 — 목록 이탈 유예)
  const handlePopoverOpenChange = useCallback((noteId: string, open: boolean) => {
    setPopoverNoteId((current) => (open ? noteId : current === noteId ? null : current))
  }, [])

  const handleEscapeFromNormal = useCallback((index: number) => {
    setFocusedIndex(index)
    feedRef.current?.focus()
  }, [])

  const handleKeyDown = useCallback((e: React.KeyboardEvent) => {
    // 텍스트 입력 영역에서 버블링된 이벤트 무시
    if (isTextInputTarget(e.target)) return

    // Escape로 포커스 해제 (피드에 직접 포커스가 있을 때만)
    if (e.key === 'Escape') {
      e.preventDefault()
      setFocusedIndex(null)
    }
  }, [])

  // grouped와 렌더링 순서에 맞는 orderedNotes를 함께 계산
  const { grouped, orderedNotes } = useMemo(() => {
    const groups: { date: string; items: typeof flatNotes }[] = []

    // Pinned 노트 분리 (root level만)
    const pinnedItems = flatNotes.filter((item) => item.depth === 0 && item.note.isPinned)
    const unpinnedItems = flatNotes.filter((item) => item.depth > 0 || !item.note.isPinned)

    // Pinned 그룹 추가 (pinnedAt 기준 내림차순 정렬)
    if (pinnedItems.length > 0) {
      const sortedPinned = [...pinnedItems].sort((a, b) => {
        const aTime = a.note.pinnedAt?.getTime() ?? 0
        const bTime = b.note.pinnedAt?.getTime() ?? 0
        return bTime - aTime
      })
      groups.push({ date: 'Pinned', items: sortedPinned })
    }

    // 일반 노트 날짜별 그룹화
    for (const item of unpinnedItems) {
      if (item.depth > 0 && groups.length > 0) {
        groups[groups.length - 1].items.push(item)
      } else {
        const date = new Date(item.note.createdAt).toLocaleDateString('ko-KR', {
          year: 'numeric',
          month: 'long',
          day: 'numeric',
        })
        const lastGroup = groups[groups.length - 1]
        if (lastGroup?.date === date) {
          lastGroup.items.push(item)
        } else {
          groups.push({ date, items: [item] })
        }
      }
    }

    // 렌더링 순서대로 평탄화 (네비게이션용)
    const ordered = groups.flatMap((g) => g.items)

    return { grouped: groups, orderedNotes: ordered }
  }, [flatNotes])

  // noteId -> index 맵 (O(1) 조회용) - orderedNotes 기준 (렌더링 순서)
  const noteIndexMap = useMemo(() => {
    const map = new Map<string, number>()
    orderedNotes.forEach((item, index) => map.set(item.note.id, index))
    return map
  }, [orderedNotes])

  // orderedNotes ref 업데이트 (이벤트 핸들러에서 최신 값 참조용)
  useEffect(() => {
    orderedNotesRef.current = orderedNotes
  }, [orderedNotes])

  const cardElementRefs = useRef<Map<string, HTMLDivElement>>(new Map())

  const setCardRef = (id: string, handle: NoteCardHandle | null) => {
    if (handle) {
      cardRefs.current.set(id, handle)
    } else {
      cardRefs.current.delete(id)
    }
  }

  // 포커스된 카드로 스크롤 (requestAnimationFrame으로 최적화)
  useEffect(() => {
    if (focusedIndex === null) return
    const item = orderedNotes[focusedIndex]
    if (!item) return

    // requestAnimationFrame으로 스크롤 배치 처리
    const rafId = requestAnimationFrame(() => {
      const element = cardElementRefs.current.get(item.note.id)
      if (!element) return

      const container = feedRef.current
      if (!container) return

      const rect = element.getBoundingClientRect()
      const containerRect = container.getBoundingClientRect()

      // 목표 scrollTop을 직접 계산한다 — scrollIntoView({ block: 'nearest' })는
      // 헤더 오프셋을 적용하지 않아 카드가 헤더 아래에 걸린 채 멈춘다 (BRU-23)
      const nextScrollTop = computeFeedScrollTop({
        currentScrollTop: container.scrollTop,
        elementOffsetTop: rect.top - containerRect.top + container.scrollTop,
        elementHeight: rect.height,
        viewportHeight: container.clientHeight,
        topInset: FEED_TOP_INSET,
      })

      if (nextScrollTop !== container.scrollTop) {
        // 키보드 이동은 즉시 반영한다 — 애니메이션이 붙으면 연타 시 위치가 밀린다.
        // 움직임이 없으므로 prefers-reduced-motion과도 충돌하지 않는다.
        container.scrollTop = nextScrollTop
      }
    })

    return () => cancelAnimationFrame(rafId)
  }, [focusedIndex, orderedNotes])

  useEffect(() => {
    if (selectedNoteId) {
      const index = noteIndexMap.get(selectedNoteId)
      if (index !== undefined) {
        setFocusedIndex(index)
      }
      // Clear selectedNoteId after navigation to prevent unwanted focus jumps
      // when noteIndexMap changes (e.g., real-time updates)
      selectNote(null)
    }
  }, [selectedNoteId, noteIndexMap, selectNote])

  // 새 노트 생성 후 해당 노트 편집 모드로
  const handleCreateNote = useCallback(async () => {
    const note = await createNote()
    setTimeout(() => {
      cardRefs.current.get(note.id)?.focus()
    }, 50)
  }, [createNote])

  const handleSearchSelect = useCallback(
    (noteId: string) => {
      const index = noteIndexMap.get(noteId)
      if (index !== undefined) {
        setFocusedIndex(index)
        setTimeout(() => {
          const element = cardElementRefs.current.get(noteId)
          element?.scrollIntoView({ behavior: 'smooth', block: 'center' })
        }, 50)
      }
    },
    [noteIndexMap]
  )

  // n 단축키로 새 노트 생성 (텍스트 입력 중 제외)
  useEffect(() => {
    const handleGlobalKeyDown = (e: KeyboardEvent) => {
      if (isTextInputTarget(e.target)) return
      if (!isCreateNoteShortcut(e)) return
      e.preventDefault()
      handleCreateNote()
    }

    window.addEventListener('keydown', handleGlobalKeyDown)
    return () => window.removeEventListener('keydown', handleGlobalKeyDown)
  }, [handleCreateNote])

  useEffect(() => {
    const handleSearchKeyDown = (e: KeyboardEvent) => {
      if (!isSearchShortcut(e)) return
      e.preventDefault()
      setShowSearchDialog(true)
    }

    window.addEventListener('keydown', handleSearchKeyDown)
    return () => window.removeEventListener('keydown', handleSearchKeyDown)
  }, [])

  // t 단축키로 카드 아래 태그 팝오버 열기 (텍스트 입력 중 제외)
  useEffect(() => {
    const handleTagListKeyDown = (e: KeyboardEvent) => {
      if (isTextInputTarget(e.target)) return
      if (!isOpenTagListShortcut(e)) return
      const fallbackNoteId = focusedIndex !== null ? orderedNotes[focusedIndex]?.note.id : null
      const noteId = getClosestNoteId(document.activeElement) ?? fallbackNoteId
      if (!noteId) return
      e.preventDefault()
      e.stopPropagation()
      cardRefs.current.get(noteId)?.openTagPopover()
    }

    window.addEventListener('keydown', handleTagListKeyDown)
    return () => window.removeEventListener('keydown', handleTagListKeyDown)
  }, [flatNotes, focusedIndex])

  // Shift+C 단축키로 포커스된 노트의 댓글 패널 열기 (BRU-63).
  // 잠긴 노트는 열지 않는다 — 내용도 댓글도 흘리지 않는다.
  useEffect(() => {
    const handleCommentsKeyDown = (e: KeyboardEvent) => {
      if (isTextInputTarget(e.target)) return
      if (!isOpenCommentsShortcut(e)) return
      const index = focusedIndexRef.current
      const fallbackNoteId = index !== null ? orderedNotesRef.current[index]?.note.id : null
      const noteId = getClosestNoteId(document.activeElement) ?? fallbackNoteId
      if (!noteId) return

      const state = useNotesStore.getState()
      const note = orderedNotesRef.current.find((item) => item.note.id === noteId)?.note
      if (!note) return
      if (note.isLocked && !state.temporarilyUnlockedNoteIds.has(note.id)) return

      e.preventDefault()
      e.stopPropagation()
      state.openComments(noteId)
    }

    window.addEventListener('keydown', handleCommentsKeyDown)
    return () => window.removeEventListener('keydown', handleCommentsKeyDown)
  }, [])

  // Cmd+T 단축키로 태그 관리 다이얼로그 열기
  useEffect(() => {
    const handleTagManagementKeyDown = (e: KeyboardEvent) => {
      if (isTextInputTarget(e.target)) return
      if (!isOpenTagManagementShortcut(e)) return
      e.preventDefault()
      e.stopPropagation()
      setShowTagManagement(true)
    }

    window.addEventListener('keydown', handleTagManagementKeyDown)
    return () => window.removeEventListener('keydown', handleTagManagementKeyDown)
  }, [])

  // Cmd+L 단축키로 노트 잠금 토글
  useEffect(() => {
    const handleLockKeyDown = (e: KeyboardEvent) => {
      if (!isToggleLockShortcut(e)) return
      const fallbackNoteId = focusedIndex !== null ? orderedNotes[focusedIndex]?.note.id : null
      const noteId = getClosestNoteId(document.activeElement) ?? fallbackNoteId
      if (!noteId) return
      e.preventDefault()
      e.stopPropagation()

      const note = notes.find((n) => n.id === noteId)
      if (!note) return

      // 잠금하려는데 PIN이 없으면 설정 다이얼로그 표시
      if (!note.isLocked && !hasPin) {
        setPinDialogMode('setup')
        setPinDialogNoteId(noteId)
        return
      }

      // 잠금 해제하려면 PIN 확인 필요 (일시 해제)
      if (note.isLocked) {
        setPinDialogMode('unlock-temp')
        setPinDialogNoteId(noteId)
        return
      }

      // 잠금 설정
      lockNote(noteId)
    }

    window.addEventListener('keydown', handleLockKeyDown)
    return () => window.removeEventListener('keydown', handleLockKeyDown)
  }, [flatNotes, focusedIndex, notes, hasPin, lockNote])

  // d 단축키로 삭제 (휴지통으로)
  useEffect(() => {
    const handleDeleteKeyDown = (e: KeyboardEvent) => {
      if (isTextInputTarget(e.target)) return
      if (!isDeleteShortcut(e)) return
      if (viewMode !== 'active') return

      const fallbackNoteId = focusedIndex !== null ? orderedNotes[focusedIndex]?.note.id : null
      const noteId = getClosestNoteId(document.activeElement) ?? fallbackNoteId
      if (!noteId) return

      e.preventDefault()
      e.stopPropagation()
      // 확인 다이얼로그를 거친다 (BRU-24)
      requestDeleteNote(noteId)
    }

    window.addEventListener('keydown', handleDeleteKeyDown)
    return () => window.removeEventListener('keydown', handleDeleteKeyDown)
  }, [flatNotes, focusedIndex, viewMode, requestDeleteNote])

  // e 단축키로 보관
  useEffect(() => {
    const handleArchiveKeyDown = (e: KeyboardEvent) => {
      if (isTextInputTarget(e.target)) return
      if (!isArchiveShortcut(e)) return
      if (viewMode !== 'active') return

      const fallbackNoteId = focusedIndex !== null ? orderedNotes[focusedIndex]?.note.id : null
      const noteId = getClosestNoteId(document.activeElement) ?? fallbackNoteId
      if (!noteId) return

      e.preventDefault()
      e.stopPropagation()
      // 보관 — 실행 취소 토스트로 복구 가능
      archiveNote(noteId)
    }

    window.addEventListener('keydown', handleArchiveKeyDown)
    return () => window.removeEventListener('keydown', handleArchiveKeyDown)
  }, [flatNotes, focusedIndex, viewMode, archiveNote])

  // r 단축키로 복원
  useEffect(() => {
    const handleRestoreKeyDown = (e: KeyboardEvent) => {
      if (isTextInputTarget(e.target)) return
      if (!isRestoreShortcut(e)) return

      const fallbackNoteId = focusedIndex !== null ? orderedNotes[focusedIndex]?.note.id : null
      const noteId = getClosestNoteId(document.activeElement) ?? fallbackNoteId
      if (!noteId) return

      e.preventDefault()
      e.stopPropagation()

      if (viewMode === 'trash') {
        restoreNote(noteId)
      } else if (viewMode === 'archived') {
        unarchiveNote(noteId)
      }
    }

    window.addEventListener('keydown', handleRestoreKeyDown)
    return () => window.removeEventListener('keydown', handleRestoreKeyDown)
  }, [flatNotes, focusedIndex, viewMode, restoreNote, unarchiveNote])

  // 초기 포커스
  useEffect(() => {
    feedRef.current?.focus()
  }, [])

  // 글로벌 j/k 네비게이션 (ref 패턴으로 의존성 분리)
  useEffect(() => {
    const handleGlobalNavigation = (e: KeyboardEvent) => {
      const currentOrderedNotes = orderedNotesRef.current
      const currentFocusedIndex = focusedIndexRef.current

      if (currentOrderedNotes.length === 0) return
      if (isTextInputTarget(e.target)) return

      const action = resolveNoteFeedShortcut(e as unknown as React.KeyboardEvent)
      if (!action) return

      if (action === 'focusNext') {
        e.preventDefault()
        if (currentFocusedIndex === null) {
          setFocusedIndex(0)
        } else {
          const nextIndex = Math.min(currentFocusedIndex + 1, currentOrderedNotes.length - 1)
          setFocusedIndex(nextIndex)
        }
        feedRef.current?.focus()
        return
      }

      if (action === 'focusPrev') {
        e.preventDefault()
        if (currentFocusedIndex === null) {
          setFocusedIndex(currentOrderedNotes.length - 1)
        } else {
          const prevIndex = Math.max(currentFocusedIndex - 1, 0)
          setFocusedIndex(prevIndex)
        }
        feedRef.current?.focus()
        return
      }

      if (action === 'openFocused') {
        if (currentFocusedIndex === null) return
        e.preventDefault()
        const item = currentOrderedNotes[currentFocusedIndex]
        if (item) {
          cardRefs.current.get(item.note.id)?.focus()
          // Keep focusedIndex so navigation continues from this position after editing
        }
        return
      }

      if (action === 'deleteFocused') {
        if (currentFocusedIndex === null) return
        e.preventDefault()
        const item = currentOrderedNotes[currentFocusedIndex]
        if (item) {
          // 확인 다이얼로그를 거친다 (BRU-24)
          requestDeleteNoteRef.current(item.note.id)
          if (currentOrderedNotes.length > 1) {
            const nextIndex =
              currentFocusedIndex >= currentOrderedNotes.length - 1
                ? currentFocusedIndex - 1
                : currentFocusedIndex
            setFocusedIndex(nextIndex)
          } else {
            setFocusedIndex(null)
          }
        }
        return
      }

      if (action === 'replyToFocused') {
        if (currentFocusedIndex === null) return
        e.preventDefault()
        const item = currentOrderedNotes[currentFocusedIndex]
        if (item) {
          handleReplyRef.current(item.note.id)
          setFocusedIndex(null)
        }
        return
      }

      if (action === 'createSibling') {
        if (currentFocusedIndex === null) return
        e.preventDefault()
        const item = currentOrderedNotes[currentFocusedIndex]
        if (item) {
          // 현재 노트의 parentId를 사용하여 같은 레벨에 노트 생성
          handleCreateSiblingRef.current(item.note.parentId)
          setFocusedIndex(null)
        }
        return
      }

      if (action?.startsWith('setPriority')) {
        if (currentFocusedIndex === null) return
        e.preventDefault()
        const item = currentOrderedNotes[currentFocusedIndex]
        if (item) {
          const priority = parseInt(action.slice(-1), 10)
          updateNotePriorityRef.current(item.note.id, priority)
        }
        return
      }

      if (action === 'copyFocused') {
        if (currentFocusedIndex === null) return
        e.preventDefault()
        const item = currentOrderedNotes[currentFocusedIndex]
        if (item) {
          navigator.clipboard.writeText(item.note.content)
        }
        return
      }

      if (action === 'togglePin') {
        if (currentFocusedIndex === null) return
        e.preventDefault()
        const item = currentOrderedNotes[currentFocusedIndex]
        if (item) {
          togglePinNoteRef.current(item.note.id)
        }
        return
      }
    }

    window.addEventListener('keydown', handleGlobalNavigation)
    return () => window.removeEventListener('keydown', handleGlobalNavigation)
  }, []) // 빈 의존성 - refs로 최신 값 참조

  // 글로벌 붙여넣기 -> 새 노트 생성 (에디터에 포커스 없을 때)
  useEffect(() => {
    const handlePaste = async (e: globalThis.ClipboardEvent) => {
      // 에디터에 포커스가 있으면 무시 (에디터가 직접 처리)
      if (isTextInputTarget(document.activeElement)) return

      const items = e.clipboardData?.items
      if (!items) return

      // 파일/이미지 처리
      for (const item of items) {
        if (item.kind === 'file') {
          const file = item.getAsFile()
          if (!file) continue

          e.preventDefault()
          await createNoteWithFile(file)
          return
        }
      }

      // 텍스트 처리
      const text = e.clipboardData?.getData('text/plain')
      if (text) {
        e.preventDefault()

        // Instagram URL 처리
        const instagramUrls = extractInstagramUrls(text)
        if (instagramUrls.length > 0) {
          for (const url of instagramUrls) {
            const note = await createNoteWithInstagram(url)
            if (note) {
              setTimeout(() => {
                cardRefs.current.get(note.id)?.focus()
              }, 50)
            }
          }
          return
        }

        // YouTube URL 처리
        const youtubeUrls = extractYouTubeUrls(text)
        if (youtubeUrls.length > 0) {
          for (const url of youtubeUrls) {
            const note = await createNoteWithYouTube(url)
            if (note) {
              setTimeout(() => {
                cardRefs.current.get(note.id)?.focus()
              }, 50)
            }
          }
          return
        }

        // 큰 텍스트는 텍스트 첨부파일로 처리 (둘 다 충족해야 함)
        const lineCount = text.split('\n').length
        const isLargeText =
          lineCount >= LARGE_TEXT_THRESHOLD_LINES && text.length >= LARGE_TEXT_THRESHOLD_CHARS

        if (isLargeText) {
          const firstLine = text.split('\n')[0].slice(0, 50)
          const title = firstLine || `붙여넣기 (${lineCount}줄)`
          const textFile = new File([text], `${title}.txt`, { type: 'text/plain' })
          await createNoteWithFile(textFile)
        } else {
          // 짧은 텍스트는 노트 본문으로
          const note = await createNote(text)
          setTimeout(() => {
            cardRefs.current.get(note.id)?.focus()
          }, 50)
        }
      }
    }

    document.addEventListener('paste', handlePaste)
    return () => document.removeEventListener('paste', handlePaste)
  }, [createNote, createNoteWithFile, createNoteWithInstagram, createNoteWithYouTube])

  return (
    <div
      ref={feedRef}
      className={`feed ${isDragOver ? 'drag-over' : ''}`}
      tabIndex={0}
      onKeyDown={handleKeyDown}
      onDragOver={handleDragOver}
      onDragLeave={handleDragLeave}
      onDrop={handleDrop}
    >
      {showTagManagement && (
        <TagManagementDialog onClose={() => setShowTagManagement(false)} />
      )}
      {showSearchDialog && (
        <SearchDialog
          onClose={() => setShowSearchDialog(false)}
          onSelectNote={handleSearchSelect}
        />
      )}
      {pinDialogNoteId && (
        <PinDialog
          mode={pinDialogMode}
          onSuccess={() => {
            const noteId = pinDialogNoteId
            setPinDialogNoteId(null)
            if (pinDialogMode === 'setup') {
              lockNote(noteId)
            } else if (pinDialogMode === 'unlock-temp') {
              temporarilyUnlockNote(noteId)
            }
          }}
          onCancel={() => setPinDialogNoteId(null)}
        />
      )}
      {pendingDeleteNote && (
        <ConfirmDialog
          title="노트를 삭제할까요?"
          message={buildDeleteConfirmMessage({
            content: pendingDeleteNote.content,
            attachmentCount: pendingDeleteNote.attachments.length,
          })}
          confirmLabel="삭제"
          danger
          onConfirm={() => {
            void confirmDeleteNote()
          }}
          onCancel={cancelDeleteNote}
        />
      )}
      {showEmptyTrashConfirm && (
        <ConfirmDialog
          title="휴지통 비우기"
          message="휴지통의 모든 노트가 영구 삭제됩니다. 복원할 수 없습니다."
          confirmLabel="비우기"
          danger
          onConfirm={() => {
            setShowEmptyTrashConfirm(false)
            emptyTrash()
          }}
          onCancel={() => setShowEmptyTrashConfirm(false)}
        />
      )}
      {showUnlockAllDialog && (
        <PinDialog
          mode="unlock-all"
          onSuccess={() => {
            setShowUnlockAllDialog(false)
            temporarilyUnlockAll()
          }}
          onCancel={() => setShowUnlockAllDialog(false)}
        />
      )}
      <div className="feed-header">
        <div className="feed-header-row">
          <ViewModeSelector />
          {viewMode === 'active' && (
            <>
              <div className="feed-header-divider" />
              <InboxFilter />
              <ExportedFilter />
              <div className="feed-header-divider" />
              <CategoryFilter />
              {filterTag && (
                <div className="filter-indicator">
                  <span>#{filterTag}</span>
                  <button
                    onClick={() => setFilterTag(null)}
                    title="태그 필터 해제"
                    aria-label="태그 필터 해제"
                  >
                    <Icon name="x" size={12} />
                  </button>
                </div>
              )}
            </>
          )}
          <div className="feed-header-spacer" />
          {viewMode === 'active' && (
            <>
              {hasLockedNotes() && (
                <button
                  className="icon-btn"
                  onClick={() => setShowUnlockAllDialog(true)}
                  title="전체 잠금 해제"
                  aria-label="전체 잠금 해제"
                >
                  <Icon name="lock-open" />
                </button>
              )}
              <button
                className="icon-btn"
                onClick={() => setShowSearchDialog(true)}
                title="검색 (⌘K)"
                aria-label="검색"
              >
                <Icon name="search" />
              </button>
            </>
          )}
          {viewMode === 'trash' && trashedNotes.length > 0 && (
            <button className="empty-trash-btn" onClick={() => setShowEmptyTrashConfirm(true)}>
              비우기
            </button>
          )}
        </div>
      </div>
      <div className="feed-content">
        {isLoading && viewMode === 'active' && orderedNotes.length === 0 ? (
          // 로딩 중 스켈레톤 카드
          <div className="feed-skeleton" aria-hidden="true">
            {[0, 1, 2, 3].map((i) => (
              <div key={i} className="skeleton-card">
                <div className="skeleton-line skeleton-line-sm" />
                <div className="skeleton-line" />
                <div className="skeleton-line skeleton-line-lg" />
              </div>
            ))}
          </div>
        ) : orderedNotes.length === 0 ? (
          // 빈 상태 (뷰 모드별 안내)
          <div className="feed-empty">
            {viewMode === 'trash' ? (
              <p>휴지통이 비어 있습니다</p>
            ) : viewMode === 'archived' ? (
              <p>보관된 노트가 없습니다</p>
            ) : filterTag ? (
              <>
                <p>'#{filterTag}' 태그의 노트가 없습니다</p>
                <button className="feed-empty-action" onClick={() => setFilterTag(null)}>
                  필터 해제
                </button>
              </>
            ) : inboxOnly ? (
              <>
                <p>분류할 노트가 없습니다 — Inbox가 비었어요</p>
                <button className="feed-empty-action" onClick={() => setInboxOnly(false)}>
                  전체 노트 보기
                </button>
              </>
            ) : categoryFilter && categoryFilter !== 'all' ? (
              <p>이 카테고리에 해당하는 노트가 없습니다</p>
            ) : (
              <>
                <p>아직 노트가 없습니다</p>
                <p className="feed-empty-hint">
                  <kbd>n</kbd> 키를 누르거나 붙여넣기로 바로 노트를 만들 수 있어요
                </p>
                <button className="feed-empty-action" onClick={handleCreateNote}>
                  첫 노트 만들기
                </button>
              </>
            )}
          </div>
        ) : (
        grouped.map(({ date, items }) => (
          <div key={date} className="date-group">
            <div className="date-label">{date}</div>
            {items.map((item) => {
              const globalIndex = noteIndexMap.get(item.note.id) ?? -1
              return (
                <div
                  key={item.note.id}
                  ref={(el) => {
                    if (el) cardElementRefs.current.set(item.note.id, el)
                    else cardElementRefs.current.delete(item.note.id)
                  }}
                  onClick={() => setFocusedIndex(globalIndex)}
                >
                  <NoteCard
                    ref={(handle) => setCardRef(item.note.id, handle)}
                    note={item.note}
                    depth={item.depth}
                    viewMode={viewMode}
                    isFocused={focusedIndex === globalIndex}
                    onEscapeFromNormal={() => handleEscapeFromNormal(globalIndex)}
                    onReply={viewMode === 'active' ? handleReply : undefined}
                    onPopoverOpenChange={handlePopoverOpenChange}
                  />
                </div>
              )
            })}
          </div>
        ))
        )}
      </div>
    </div>
  )
}
