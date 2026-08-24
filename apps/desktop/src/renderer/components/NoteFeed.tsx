import { useRef, useState, useCallback, useEffect, useMemo } from 'react'
import type { Note } from '@drop/shared'
import { useNotesStore } from '../stores/notes'
import { useProfileStore } from '../stores/profile'
import { NoteCard, NoteCardHandle } from './NoteCard'
import { TagManagementDialog } from './TagManagementDialog'
import { CategoryFilter } from './CategoryFilter'
import { InboxFilter } from './InboxFilter'
import { ProjectFilter } from './ProjectFilter'
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
import { shouldYieldToNativeCopy } from '../lib/copy-guard'
import { buildNoteReference } from '../../shared/note-reference'
import { extractInstagramUrls } from '../lib/instagram-url-utils'
import { buildDeleteConfirmMessage } from '../lib/delete-confirm'
import { scrollFocusedNoteIntoView } from '../lib/feed-scroll'
import { applyNoteFilters } from '../lib/note-filters'
import { buildNoteRows } from '../lib/note-hierarchy'
import { resolveNoteSelectionShortcut } from '../shortcuts/noteSelection'
import {
  enterVisualSelection,
  extendSelection,
  resolveSelectedNotes,
  selectionScopeKey,
  type VisualSelection,
} from '../lib/note-selection'
import { buildBulkDeleteConfirmMessage, type BulkActionId } from '../lib/bulk-actions'
import { mapWithConcurrency } from '../lib/concurrency'
import { SelectionActionBar } from './SelectionActionBar'
import { BulkTagPopover } from './BulkTagPopover'

// 일괄 액션을 한 번에 몇 건까지 동시에 보낼지. 왕복 지연을 감추면서도
// 노트당 목록 재조회가 한꺼번에 몰리지 않는 선이다.
const BULK_ACTION_CONCURRENCY = 8

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
    filterProjectId,
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
    permanentlyDeleteNote,
    emptyTrash,
    archiveNote,
    unarchiveNote,
    updateNotePriority,
    togglePinNote,
    selectedNoteId,
    selectNote,
  } = useNotesStore()
  const [focusedIndex, setFocusedIndex] = useState<number | null>(null)
  // 비주얼 선택 (BRU-80). 앵커·헤드만 들고 범위는 lib/note-selection.ts가 계산한다.
  const [selection, setSelection] = useState<VisualSelection | null>(null)
  const [showBulkTagPopover, setShowBulkTagPopover] = useState(false)
  const [pendingBulkDelete, setPendingBulkDelete] = useState<
    'trash' | 'deletePermanently' | null
  >(null)
  const [showTagManagement, setShowTagManagement] = useState(false)
  const [pinDialogNoteId, setPinDialogNoteId] = useState<string | null>(null)
  const [pinDialogMode, setPinDialogMode] = useState<PinDialogMode>('setup')
  const [showUnlockAllDialog, setShowUnlockAllDialog] = useState(false)
  const [showSearchDialog, setShowSearchDialog] = useState(false)
  const [showEmptyTrashConfirm, setShowEmptyTrashConfirm] = useState(false)
  // 지금 팝오버가 열려 있는 노트 (필터에서 목록 이탈을 유예하는 데 쓴다)
  const [popoverNoteId, setPopoverNoteId] = useState<string | null>(null)
  // 목록 전체 펼치기 (BRU-79). 훑어보기용 일시 토글이라 **세션 간 유지하지 않는다** —
  // 스토어가 아니라 여기 로컬 state에 두는 것이 그 결정의 구조적 보장이다.
  const [expandAll, setExpandAll] = useState(false)
  const hasPin = useProfileStore((s) => s.hasPin)
  const cardRefs = useRef<Map<string, NoteCardHandle>>(new Map())
  const feedRef = useRef<HTMLDivElement>(null)

  // 이벤트 핸들러용 ref (의존성 분리) - 나중에 업데이트됨
  const focusedIndexRef = useRef<number | null>(focusedIndex)
  const selectionRef = useRef<VisualSelection | null>(selection)
  // 일괄 삭제 확인 다이얼로그가 떠 있는지. Esc가 다이얼로그 대신 선택만 푸는 것을 막는다.
  const pendingBulkDeleteRef = useRef<typeof pendingBulkDelete>(pendingBulkDelete)
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
      filterProjectId,
      inboxOnly,
      showExported,
      retainedNoteIds,
    })
  }, [
    viewMode,
    baseNotes,
    filterTag,
    categoryFilter,
    filterProjectId,
    inboxOnly,
    showExported,
    retainedNoteIds,
  ])

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
    selectionRef.current = selection
  }, [selection])

  useEffect(() => {
    pendingBulkDeleteRef.current = pendingBulkDelete
  }, [pendingBulkDelete])

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

    if (e.key === 'Escape') {
      // 확인 다이얼로그가 떠 있으면 Esc는 다이얼로그를 닫는다 (ConfirmDialog가 캡처 단계에서
      // 받아 간다). 여기서 선택을 풀면 "0개 삭제" 문구만 남는다.
      if (pendingBulkDeleteRef.current) return
      e.preventDefault()
      // 선택 중이면 Esc는 선택만 푼다 — 포커스까지 잃으면 이어서 j/k를 칠 수 없다 (BRU-80)
      if (selectionRef.current) {
        setSelection(null)
        return
      }
      // Escape로 포커스 해제 (피드에 직접 포커스가 있을 때만)
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

      // 목표 scrollTop을 직접 계산한다 — scrollIntoView({ block: 'nearest' })는
      // 헤더 오프셋을 적용하지 않아 카드가 헤더 아래에 걸린 채 멈춘다 (BRU-23).
      // 적용 대상은 카드의 실제 스크롤 조상이다 — 피드 래퍼는 스크롤하지 않는다 (BRU-85).
      scrollFocusedNoteIntoView(element, FEED_TOP_INSET)
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

  // ── 일괄 액션 (BRU-80) ──────────────────────────────────────────────
  // 렌더 순서 그대로의 노트 목록. 선택은 여기에 대고 매번 다시 푼다 —
  // 액션 바가 보여주는 개수도, 실제로 지워지는 노트도 이 배열 하나에서 나온다.
  const orderedNoteList = useMemo(() => orderedNotes.map((item) => item.note), [orderedNotes])

  const selectedNotes = useMemo(
    () => resolveSelectedNotes(selection, orderedNoteList),
    [selection, orderedNoteList]
  )

  const selectedNoteIdSet = useMemo(
    () => new Set(selectedNotes.map((note) => note.id)),
    [selectedNotes]
  )

  const clearSelection = useCallback(() => {
    setSelection(null)
    setShowBulkTagPopover(false)
  }, [])

  // 목록을 바꾸는 축(뷰 모드·태그·카테고리·Inbox·내보냄)이 달라지면 선택을 버린다.
  // id 기반이라 엉뚱한 노트가 잡히지는 않지만, 남아 있는 "0개 선택" 바도 거짓말이다.
  // 렌더 중에 맞춘다 — effect로 미루면 한 프레임 동안 옛 선택이 그려진다.
  const scopeKey = selectionScopeKey({
    viewMode,
    filterTag,
    categoryFilter,
    inboxOnly,
    showExported,
  })
  const [selectionScope, setSelectionScope] = useState(scopeKey)
  if (selectionScope !== scopeKey) {
    setSelectionScope(scopeKey)
    setSelection(null)
    setShowBulkTagPopover(false)
  }

  const runOnTargets = useCallback(async (targets: string[], run: (id: string) => Promise<void>) => {
    // 직렬 await은 50건이면 왕복 지연이 그대로 쌓여 몇 초간 무반응이 된다.
    // 그렇다고 전부 동시에 쏘면 목록 재조회가 같이 폭발한다 — 상한을 두고 병렬로 흘린다.
    await mapWithConcurrency(targets, BULK_ACTION_CONCURRENCY, run)
  }, [])

  const handleBulkAction = useCallback(
    async (action: BulkActionId) => {
      if (action === 'tag') {
        setShowBulkTagPopover(true)
        return
      }

      // 삭제는 한 장일 때와 똑같이 확인을 거친다 (BRU-24)
      if (action === 'trash' || action === 'deletePermanently') {
        setPendingBulkDelete(action)
        return
      }

      // 목록을 먼저 복사한다 — 처리 중에 선택이 비워지기 때문이다
      const targets = selectedNotes.map((note) => note.id)
      clearSelection()

      await runOnTargets(targets, async (id) => {
        if (action === 'archive') await archiveNote(id)
        else if (action === 'unarchive') await unarchiveNote(id)
        else if (action === 'restore') await restoreNote(id)
      })
    },
    [selectedNotes, clearSelection, runOnTargets, archiveNote, unarchiveNote, restoreNote]
  )

  const confirmBulkDelete = useCallback(async () => {
    const action = pendingBulkDelete
    const targets = selectedNotes.map((note) => note.id)
    setPendingBulkDelete(null)
    clearSelection()

    await runOnTargets(targets, async (id) => {
      if (action === 'deletePermanently') await permanentlyDeleteNote(id)
      else await deleteNote(id)
    })
  }, [
    pendingBulkDelete,
    selectedNotes,
    clearSelection,
    runOnTargets,
    deleteNote,
    permanentlyDeleteNote,
  ])

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

      // 선택 키가 먼저다 — Shift+J/K는 피드 리졸버가 보지 않는 자리다 (BRU-80)
      const selectionAction = resolveNoteSelectionShortcut(e as unknown as React.KeyboardEvent)
      if (selectionAction) {
        const currentSelection = selectionRef.current
        const orderedIds = currentOrderedNotes.map((item) => item.note.id)

        if (selectionAction === 'exitVisual') {
          // 확인 다이얼로그가 떠 있으면 Esc는 다이얼로그의 것이다 —
          // 선택만 풀면 "0개 삭제" 문구가 남은 채 확인해도 아무것도 안 지워진다.
          if (pendingBulkDeleteRef.current) return
          if (!currentSelection) return
          e.preventDefault()
          setSelection(null)
          return
        }

        if (selectionAction === 'enterVisual') {
          e.preventDefault()
          const startIndex = currentFocusedIndex ?? 0
          setFocusedIndex(startIndex)
          setSelection(enterVisualSelection(orderedIds[startIndex]))
          return
        }

        // 선택에 들어가지 않은 상태의 Shift+J/K는 그 자리에서 선택을 연다
        const base = currentSelection ?? enterVisualSelection(orderedIds[currentFocusedIndex ?? 0])
        const direction = selectionAction === 'extendNext' ? 1 : -1
        const next = extendSelection(base, direction, orderedIds)
        if (!next) return

        e.preventDefault()
        setSelection(next)
        // 머리를 따라 포커스도 움직여야 화면이 따라온다 (BRU-85의 스크롤 경로를 그대로 탄다)
        setFocusedIndex(orderedIds.indexOf(next.headId))
        return
      }

      const action = resolveNoteFeedShortcut(e as unknown as React.KeyboardEvent)
      if (!action) return

      if (action === 'focusNext') {
        e.preventDefault()
        // 맨 j/k는 선택을 벗어나는 이동이다
        setSelection(null)
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
        setSelection(null)
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

      // 복사 두 갈래 (BRU-104): 내용만 / 에이전트가 MCP로 되짚을 수 있는 참조 링크.
      if (action === 'copyFocused' || action === 'copyFocusedReference') {
        if (currentFocusedIndex === null) return
        // 텍스트를 긁어 놓고 ⌘C를 눌렀다면 그건 선택 영역 복사다 — OS에 그대로 넘긴다.
        if (shouldYieldToNativeCopy({ selectionText: window.getSelection()?.toString() ?? null })) {
          return
        }
        e.preventDefault()
        const item = currentOrderedNotes[currentFocusedIndex]
        if (item) {
          const text =
            action === 'copyFocusedReference'
              ? buildNoteReference({
                  id: item.note.id,
                  displayId: item.note.displayId,
                  content: item.note.content,
                })
              : item.note.content
          navigator.clipboard.writeText(text)
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
      {pendingBulkDelete && (
        <ConfirmDialog
          title={
            pendingBulkDelete === 'deletePermanently'
              ? '선택한 노트를 영구 삭제할까요?'
              : '선택한 노트를 삭제할까요?'
          }
          message={buildBulkDeleteConfirmMessage(selectedNotes.length, pendingBulkDelete)}
          confirmLabel={pendingBulkDelete === 'deletePermanently' ? '영구 삭제' : '삭제'}
          danger
          onConfirm={() => {
            void confirmBulkDelete()
          }}
          onCancel={() => setPendingBulkDelete(null)}
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
              <ProjectFilter />
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
                className={`icon-btn ${expandAll ? 'active' : ''}`}
                onClick={() => setExpandAll((on) => !on)}
                title={expandAll ? '모두 접기' : '모두 펼쳐보기'}
                aria-label={expandAll ? '모두 접기' : '모두 펼쳐보기'}
                aria-pressed={expandAll}
              >
                <Icon name={expandAll ? 'chevrons-up' : 'chevrons-down'} />
              </button>
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
                  className={
                    selectedNoteIdSet.has(item.note.id) ? 'note-row selected' : 'note-row'
                  }
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
                    expandAll={expandAll}
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
      {/* 선택이 실제로 가리키는 노트가 있을 때만 띄운다 — realtime 삭제로 범위가 비면
          "0개 선택" 바만 남는다 */}
      {selectedNotes.length > 0 && (
        <div className="selection-bar-layer">
          {showBulkTagPopover && (
            <BulkTagPopover
              notes={selectedNotes}
              onClose={() => setShowBulkTagPopover(false)}
            />
          )}
          <SelectionActionBar
            count={selectedNotes.length}
            viewMode={viewMode}
            onAction={handleBulkAction}
            onClear={clearSelection}
          />
        </div>
      )}
    </div>
  )
}
