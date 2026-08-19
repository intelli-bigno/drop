import type { StateCreator } from 'zustand'
import { supabase } from '../../lib/supabase'
import { useAuthStore } from '../auth'
import { tagRowToTag } from '@drop/shared'
import type { TagRow } from '@drop/shared'
import type { NotesState, TagsSlice } from './types'
import {
  applyTagAttach,
  applyTagDetach,
  isProvisionalTagId,
  provisionalTagId,
  reconcileTagId,
  resolveTagForAttach,
} from '../../lib/tag-mutations'

/**
 * 진행 중인 낙관적 부착 — 임시 id → 서버가 정한 진짜 태그 id (실패하면 null).
 *
 * 부착이 즉시 화면에 뜨므로, 서버가 답하기 전에 같은 태그를 다시 눌러 떼는 일이 생긴다
 * (팝오버는 고른 뒤에도 열려 있고 다시 누르면 뗀다). 그때 지울 행의 id를 여기서 기다린다.
 */
const pendingAttach = new Map<string, Promise<string | null>>()

export const createTagsSlice: StateCreator<NotesState, [], [], TagsSlice> = (set, get) => ({
  allTags: [],
  filterTag: null,

  loadTags: async () => {
    try {
      const { data, error } = await supabase
        .from('tags')
        .select('*')
        .order('last_used_at', { ascending: false, nullsFirst: false })

      if (error) throw error

      const allTags = (data ?? []).map((row) => tagRowToTag(row as TagRow))
      set({ allTags })
    } catch (error) {
      console.error('Failed to load tags:', error)
    }
  },

  // 태그는 캡처 직후 매번 지나는 경로다. 서버 왕복을 기다렸다가 칩을 그리면
  // 왕복 수만큼 손이 멈춘다 (실측: 왕복 1회 p50 92ms). 그래서 화면에 먼저 붙이고
  // 서버는 뒤따르게 한다. 실패하면 되돌린다. (BRU-81)
  addTagToNote: async (noteId, tagName) => {
    const user = useAuthStore.getState().user
    if (!user) {
      console.error('[tags] addTagToNote: user not authenticated')
      return
    }

    const now = new Date()
    const resolved = resolveTagForAttach({
      allTags: get().allTags,
      tagName,
      now,
      provisionalId: provisionalTagId(crypto.randomUUID()),
    })
    if (!resolved) return

    const { tag, isNew } = resolved
    const note = get().notes.find((n) => n.id === noteId)
    if (note?.tags.some((t) => t.id === tag.id)) return

    // 1. 화면 먼저 — 왕복을 기다리지 않는다
    set((state) => applyTagAttach({ notes: state.notes, allTags: state.allTags, noteId, tag }))

    const rollback = (tagId: string) =>
      set((state) =>
        applyTagDetach({
          notes: state.notes,
          allTags: state.allTags,
          noteId,
          tagId,
          dropFromAllTags: isNew,
        })
      )

    // 2. 서버는 뒤따라간다
    const nowIso = now.toISOString()
    // 되돌릴 때 화면에서 뗄 id — 서버 id로 갈아 끼운 뒤에는 그쪽이 된다
    let attachedId = tag.id
    const persist = async (): Promise<string | null> => {
      try {
        if (!isNew) {
          // 태그 id를 이미 아니까 두 요청을 나란히 보낸다 — 왕복 1회분 시간에 끝난다
          const [link, touch] = await Promise.all([
            supabase
              .from('note_tags')
              .upsert({ note_id: noteId, tag_id: tag.id }, { onConflict: 'note_id,tag_id' }),
            supabase.from('tags').update({ last_used_at: nowIso }).eq('id', tag.id),
          ])
          if (link.error) throw link.error
          // 사용 시각은 정렬 힌트일 뿐이다 — 여기서 실패해도 부착은 되돌리지 않는다
          if (touch.error) console.error('Failed to bump tag last_used_at:', touch.error)
          return tag.id
        }

        // 처음 보는 이름 — 있으면 사용 시각만 올리고 없으면 만든다 (왕복 1회)
        const { data, error } = await supabase
          .from('tags')
          .upsert(
            { name: tag.name, user_id: user.id, last_used_at: nowIso },
            { onConflict: 'name,user_id' }
          )
          .select()
          .single()
        if (error) throw error
        if (!data) throw new Error('tag upsert returned no row')

        const saved = tagRowToTag(data as TagRow)
        attachedId = saved.id
        set((state) =>
          reconcileTagId({
            notes: state.notes,
            allTags: state.allTags,
            provisionalId: tag.id,
            tag: saved,
          })
        )

        const { error: linkError } = await supabase
          .from('note_tags')
          .upsert({ note_id: noteId, tag_id: saved.id }, { onConflict: 'note_id,tag_id' })
        if (linkError) throw linkError

        return saved.id
      } catch (error) {
        console.error('Failed to add tag to note:', error)
        rollback(attachedId)
        return null
      }
    }

    const inFlight = persist()
    if (isNew) {
      pendingAttach.set(tag.id, inFlight)
      inFlight.finally(() => pendingAttach.delete(tag.id))
    }
    await inFlight
  },

  removeTagFromNote: async (noteId, tagId) => {
    const removed = get()
      .notes.find((n) => n.id === noteId)
      ?.tags.find((t) => t.id === tagId)
    if (!removed) return

    // 1. 화면 먼저
    set((state) => applyTagDetach({ notes: state.notes, allTags: state.allTags, noteId, tagId }))

    // 2. 아직 서버 id를 못 받은 태그면 그것부터 기다린다
    let serverTagId = tagId
    if (isProvisionalTagId(tagId)) {
      const settled = await pendingAttach.get(tagId)
      // 부착 자체가 실패했다면 서버에 지울 것이 없다
      if (!settled) return
      serverTagId = settled
    }

    const { error } = await supabase
      .from('note_tags')
      .delete()
      .eq('note_id', noteId)
      .eq('tag_id', serverTagId)

    if (error) {
      console.error('Failed to remove tag from note:', error)
      // 되돌린다 — 서버에는 아직 붙어 있다
      set((state) =>
        applyTagAttach({ notes: state.notes, allTags: state.allTags, noteId, tag: removed })
      )
    }
  },

  setFilterTag: (tagName) => {
    // 태그 필터를 켜면 Inbox 필터는 꺼진다 — 둘이 겹치면 결과가 항상 비어 있다 (BRU-50)
    set(tagName ? { filterTag: tagName, inboxOnly: false } : { filterTag: null })
  },

  updateTag: async (tagId, newName) => {
    const trimmedName = newName.trim().toLowerCase()
    if (!trimmedName) return

    try {
      // 1. Update tag name in database
      const { data: updatedTag, error } = await supabase
        .from('tags')
        .update({ name: trimmedName })
        .eq('id', tagId)
        .select()
        .single()

      if (error) {
        console.error('Failed to update tag:', error)
        return
      }

      const tag = tagRowToTag(updatedTag as TagRow)

      // 2. Update tag in allTags and all notes that have this tag
      set((state) => ({
        allTags: state.allTags.map((t) => (t.id === tagId ? tag : t)),
        notes: state.notes.map((note) => ({
          ...note,
          tags: note.tags.map((t) => (t.id === tagId ? tag : t)),
        })),
        // If filterTag matches the old name, update it to the new name
        filterTag:
          state.filterTag && state.allTags.find((t) => t.id === tagId)?.name === state.filterTag
            ? trimmedName
            : state.filterTag,
      }))
    } catch (error) {
      console.error('Failed to update tag:', error)
    }
  },

  deleteTag: async (tagId) => {
    try {
      // 1. Delete all note_tags relationships first
      const { error: linkError } = await supabase.from('note_tags').delete().eq('tag_id', tagId)

      if (linkError) {
        console.error('Failed to delete tag relationships:', linkError)
        return
      }

      // 2. Delete the tag itself
      const { error } = await supabase.from('tags').delete().eq('id', tagId)

      if (error) {
        console.error('Failed to delete tag:', error)
        return
      }

      // 3. Update state: remove tag from allTags and from all notes
      set((state) => {
        const deletedTag = state.allTags.find((t) => t.id === tagId)
        return {
          allTags: state.allTags.filter((t) => t.id !== tagId),
          notes: state.notes.map((note) => ({
            ...note,
            tags: note.tags.filter((t) => t.id !== tagId),
          })),
          // Clear filter if it was filtering by the deleted tag
          filterTag: deletedTag && state.filterTag === deletedTag.name ? null : state.filterTag,
        }
      })
    } catch (error) {
      console.error('Failed to delete tag:', error)
    }
  },
})
