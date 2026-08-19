import type { StateCreator } from 'zustand'
import { supabase } from '../../lib/supabase'
import { useAuthStore } from '../auth'
import { tagRowToTag } from '@drop/shared'
import type { TagRow } from '@drop/shared'
import type { Note, Tag } from '@drop/shared'
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

/** 노트가 담긴 세 배열 + 태그 목록 — 태그 전이는 항상 이 넷을 함께 옮긴다 */
type TagViews = Pick<NotesState, 'notes' | 'archivedNotes' | 'trashedNotes' | 'allTags'>

/**
 * 스토어는 활성·보관함·휴지통 노트를 각각 다른 배열로 든다. 태그 칩(과 그 × 버튼)은
 * 뷰 모드와 무관하게 렌더되므로, 전이를 활성 배열에만 걸면 보관된 노트의 태그 조작이
 * 화면에서도 서버에서도 통째로 사라진다.
 */
function acrossViews(
  state: TagViews,
  step: (notes: Note[], allTags: Tag[]) => { notes: Note[]; allTags: Tag[] }
): TagViews {
  const active = step(state.notes, state.allTags)
  const archived = step(state.archivedNotes, active.allTags)
  const trashed = step(state.trashedNotes, archived.allTags)

  return {
    notes: active.notes,
    archivedNotes: archived.notes,
    trashedNotes: trashed.notes,
    allTags: trashed.allTags,
  }
}

/** 세 배열 어디에 있든 노트를 찾는다 */
function findNote(state: TagViews, noteId: string): Note | undefined {
  return (
    state.notes.find((n) => n.id === noteId) ??
    state.archivedNotes.find((n) => n.id === noteId) ??
    state.trashedNotes.find((n) => n.id === noteId)
  )
}

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
    const note = findNote(get(), noteId)
    if (note?.tags.some((t) => t.id === tag.id)) return

    // 1. 화면 먼저 — 왕복을 기다리지 않는다
    set((state) =>
      acrossViews(state, (notes, allTags) => applyTagAttach({ notes, allTags, noteId, tag }))
    )

    // 되돌릴 때 화면에서 뗄 id — 서버 id로 갈아 끼운 뒤에는 그쪽이 된다
    let attachedId = tag.id
    // 이 자리에서 만든 태그만 목록에서도 지운다. 서버가 태그 행을 이미 만들어 준 뒤라면
    // 연결이 실패해도 태그 자체는 실재하므로 목록에서 지우면 안 된다.
    let dropFromAllTags = isNew

    const rollback = () =>
      set((state) =>
        acrossViews(state, (notes, allTags) =>
          applyTagDetach({ notes, allTags, noteId, tagId: attachedId, dropFromAllTags })
        )
      )

    // 2. 서버는 뒤따라간다
    const nowIso = now.toISOString()
    const persist = async (): Promise<string | null> => {
      try {
        if (!isNew) {
          let targetId = tag.id

          // 같은 이름을 방금 다른 노트에 처음 붙였고 서버 id가 아직 안 온 경우가 있다.
          // 그대로 보내면 'pending:…'이 uuid 자리에 실려 요청이 죽는다 — 진짜 id를 기다린다.
          if (isProvisionalTagId(targetId)) {
            const settled = await pendingAttach.get(targetId)
            // 원 부착이 실패했다면 서버에 붙일 태그 자체가 없다
            if (!settled) {
              rollback()
              return null
            }
            targetId = settled
            attachedId = settled
          }

          // 태그 id를 이미 아니까 두 요청을 나란히 보낸다 — 왕복 1회분 시간에 끝난다.
          // 사용 시각은 정렬 힌트일 뿐이라 부착과 생사를 같이 하지 않는다 → allSettled.
          const [link, touch] = await Promise.allSettled([
            supabase
              .from('note_tags')
              .upsert({ note_id: noteId, tag_id: targetId }, { onConflict: 'note_id,tag_id' }),
            supabase.from('tags').update({ last_used_at: nowIso }).eq('id', targetId),
          ])
          if (link.status === 'rejected') throw link.reason
          if (link.value.error) throw link.value.error
          if (touch.status === 'rejected') {
            console.error('Failed to bump tag last_used_at:', touch.reason)
          } else if (touch.value.error) {
            console.error('Failed to bump tag last_used_at:', touch.value.error)
          }
          return targetId
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
        // 태그 행은 서버에 실재한다 — 이 뒤로는 연결이 실패해도 목록에서 지우지 않는다
        dropFromAllTags = false
        set((state) =>
          acrossViews(state, (notes, allTags) =>
            reconcileTagId({ notes, allTags, provisionalId: tag.id, tag: saved })
          )
        )

        const { error: linkError } = await supabase
          .from('note_tags')
          .upsert({ note_id: noteId, tag_id: saved.id }, { onConflict: 'note_id,tag_id' })
        if (linkError) throw linkError

        return saved.id
      } catch (error) {
        console.error('Failed to add tag to note:', error)
        rollback()
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
    // 보관함·휴지통 노트도 × 버튼을 그대로 갖는다. 활성 배열만 보고 곧장 return하면
    // 그 노트들의 해제는 서버에 아예 나가지 않는다. 찾은 값은 롤백용으로만 쓴다.
    const removed = findNote(get(), noteId)?.tags.find((t) => t.id === tagId)

    // 1. 화면 먼저
    set((state) =>
      acrossViews(state, (notes, allTags) => applyTagDetach({ notes, allTags, noteId, tagId }))
    )

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
      if (!removed) return
      set((state) =>
        acrossViews(state, (notes, allTags) =>
          applyTagAttach({ notes, allTags, noteId, tag: removed })
        )
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
