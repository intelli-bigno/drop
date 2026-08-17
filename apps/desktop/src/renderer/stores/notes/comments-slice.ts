import type { StateCreator } from 'zustand'
import { supabase } from '../../lib/supabase'
import { useAuthStore } from '../auth'
import { useToastStore } from '../toast'
import { noteCommentRowToNoteComment } from '@drop/shared'
import type { NoteComment, NoteCommentRow } from '@drop/shared'
import type { NotesState, CommentsSlice } from './types'
import {
  countCommentsByNote,
  sortCommentsOldestFirst,
  insertOptimisticComment,
  confirmOptimisticComment,
  rollbackOptimisticComment,
  adjustCommentCount,
  normalizeCommentBody,
  canSubmitComment,
} from '../../lib/note-comments'

// 댓글은 노트가 아니다 — `notes` 배열에 절대 섞지 않는다.
// 목록 화면에는 노트별 *개수*만 있으면 되고(카드 뱃지), 본문은 패널을 열 때 읽는다.
export const createCommentsSlice: StateCreator<NotesState, [], [], CommentsSlice> = (
  set,
  get
) => ({
  commentsByNote: {},
  commentCountByNote: {},
  isCommentsLoading: false,
  commentsNoteId: null,
  pendingDeleteCommentId: null,

  openComments: (noteId) => {
    set({ commentsNoteId: noteId })
    get().loadComments(noteId)
  },

  closeComments: () => set({ commentsNoteId: null, pendingDeleteCommentId: null }),

  loadCommentCounts: async (noteIds) => {
    if (noteIds.length === 0) {
      set({ commentCountByNote: {} })
      return
    }
    try {
      const { data, error } = await supabase
        .from('note_comments')
        .select('note_id')
        .in('note_id', noteIds)

      if (error) throw error

      set({ commentCountByNote: countCommentsByNote(data ?? []) })
    } catch (error) {
      // 개수는 곁다리 정보다 — 못 읽었다고 노트 목록까지 실패시키지 않는다.
      console.error('[comments] loadCommentCounts failed', error)
    }
  },

  loadComments: async (noteId) => {
    set({ isCommentsLoading: true })
    try {
      const { data, error } = await supabase
        .from('note_comments')
        .select('*')
        .eq('note_id', noteId)
        .order('created_at', { ascending: true })

      if (error) throw error

      const comments = sortCommentsOldestFirst(
        ((data ?? []) as NoteCommentRow[]).map(noteCommentRowToNoteComment)
      )

      set((state) => ({
        commentsByNote: { ...state.commentsByNote, [noteId]: comments },
        // 목록을 실제로 읽었으니 뱃지 숫자도 여기서 맞춘다
        commentCountByNote:
          comments.length > 0
            ? { ...state.commentCountByNote, [noteId]: comments.length }
            : (() => {
                const next = { ...state.commentCountByNote }
                delete next[noteId]
                return next
              })(),
        isCommentsLoading: false,
      }))
    } catch (error) {
      console.error('[comments] loadComments failed', error)
      set({ isCommentsLoading: false })
      useToastStore.getState().showToast({
        message: '댓글을 불러오지 못했습니다',
        variant: 'error',
        actionLabel: '재시도',
        onAction: () => {
          get().loadComments(noteId)
        },
      })
    }
  },

  addComment: async (noteId, body) => {
    if (!canSubmitComment(body)) return

    const user = useAuthStore.getState().user
    if (!user) {
      console.error('[comments] addComment: user not authenticated')
      return
    }

    const trimmed = normalizeCommentBody(body)
    const optimisticId = crypto.randomUUID()
    const now = new Date()
    const optimistic: NoteComment = {
      id: optimisticId,
      noteId,
      userId: user.id,
      body: trimmed,
      createdAt: now,
      updatedAt: now,
      isPending: true,
    }

    // 낙관적 삽입 — 노트 생성 경로와 같은 방식이다 (실패하면 되돌린다).
    set((state) => ({
      commentsByNote: {
        ...state.commentsByNote,
        [noteId]: insertOptimisticComment(state.commentsByNote[noteId] ?? [], optimistic),
      },
      commentCountByNote: adjustCommentCount(state.commentCountByNote, noteId, 1),
    }))

    const { data, error } = await supabase
      .from('note_comments')
      .insert({ id: optimisticId, note_id: noteId, user_id: user.id, body: trimmed })
      .select()
      .single()

    if (error) {
      console.error('[comments] addComment failed', error)
      set((state) => ({
        commentsByNote: {
          ...state.commentsByNote,
          [noteId]: rollbackOptimisticComment(state.commentsByNote[noteId] ?? [], optimisticId),
        },
        commentCountByNote: adjustCommentCount(state.commentCountByNote, noteId, -1),
      }))
      useToastStore.getState().showToast({
        message: '댓글을 남기지 못했습니다',
        variant: 'error',
      })
      return
    }

    const saved = noteCommentRowToNoteComment(data as NoteCommentRow)
    set((state) => ({
      commentsByNote: {
        ...state.commentsByNote,
        [noteId]: confirmOptimisticComment(
          state.commentsByNote[noteId] ?? [],
          optimisticId,
          saved
        ),
      },
    }))
  },

  updateComment: async (noteId, commentId, body) => {
    if (!canSubmitComment(body)) return
    const trimmed = normalizeCommentBody(body)
    const prev = get().commentsByNote[noteId] ?? []

    set((state) => ({
      commentsByNote: {
        ...state.commentsByNote,
        [noteId]: (state.commentsByNote[noteId] ?? []).map((c) =>
          c.id === commentId ? { ...c, body: trimmed, isPending: true } : c
        ),
      },
    }))

    const { data, error } = await supabase
      .from('note_comments')
      .update({ body: trimmed })
      .eq('id', commentId)
      .select()
      .single()

    if (error) {
      console.error('[comments] updateComment failed', error)
      set((state) => ({ commentsByNote: { ...state.commentsByNote, [noteId]: prev } }))
      useToastStore.getState().showToast({
        message: '댓글을 수정하지 못했습니다',
        variant: 'error',
      })
      return
    }

    const saved = noteCommentRowToNoteComment(data as NoteCommentRow)
    set((state) => ({
      commentsByNote: {
        ...state.commentsByNote,
        [noteId]: (state.commentsByNote[noteId] ?? []).map((c) => (c.id === commentId ? saved : c)),
      },
    }))
  },

  // 댓글 삭제는 되돌릴 수 없다(휴지통 없음) — 반드시 확인을 거친다.
  requestDeleteComment: (commentId) => set({ pendingDeleteCommentId: commentId }),
  cancelDeleteComment: () => set({ pendingDeleteCommentId: null }),

  confirmDeleteComment: async () => {
    const commentId = get().pendingDeleteCommentId
    const noteId = get().commentsNoteId
    set({ pendingDeleteCommentId: null })
    if (!commentId || !noteId) return

    const prev = get().commentsByNote[noteId] ?? []

    set((state) => ({
      commentsByNote: {
        ...state.commentsByNote,
        [noteId]: (state.commentsByNote[noteId] ?? []).filter((c) => c.id !== commentId),
      },
      commentCountByNote: adjustCommentCount(state.commentCountByNote, noteId, -1),
    }))

    const { error } = await supabase.from('note_comments').delete().eq('id', commentId)

    if (error) {
      console.error('[comments] deleteComment failed', error)
      set((state) => ({
        commentsByNote: { ...state.commentsByNote, [noteId]: prev },
        commentCountByNote: adjustCommentCount(state.commentCountByNote, noteId, 1),
      }))
      useToastStore.getState().showToast({
        message: '댓글을 삭제하지 못했습니다',
        variant: 'error',
      })
    }
  },
})
