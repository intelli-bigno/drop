// 태그 부착·해제의 순수 상태 전이 (BRU-81).
//
// 태그를 다는 체감 속도를 결정하는 것은 계산이 아니라 서버 왕복이다 (실측: 왕복 1회 p50 92ms,
// 현행 부착 경로는 직렬 3회 ≈ 300ms). 그래서 화면 상태는 왕복을 기다리지 않고 여기서 먼저 만든다.
// 서버 응답은 나중에 `reconcileTagId`로 끼워 맞추고, 실패하면 `applyTagDetach`로 되돌린다.

import type { Tag } from '@drop/shared'
import { normalizeTagName } from './tag-popover'

/** 태그를 달 수 있는 최소한의 노트 모양 — 스토어의 Note도 이 모양을 만족한다 */
export interface TaggedNote {
  id: string
  tags: Tag[]
}

export interface TagState<N extends TaggedNote> {
  notes: N[]
  allTags: Tag[]
}

const PROVISIONAL_PREFIX = 'pending:'

/** 서버가 id를 주기 전까지 화면에서만 쓰는 임시 id */
export function provisionalTagId(seed: string): string {
  return `${PROVISIONAL_PREFIX}${seed}`
}

export function isProvisionalTagId(id: string): boolean {
  return id.startsWith(PROVISIONAL_PREFIX)
}

/** 최근에 쓴 태그가 앞으로 — 한 번도 안 쓴 태그는 맨 뒤. 원본은 건드리지 않는다 */
export function sortTagsByLastUsed(tags: Tag[]): Tag[] {
  return [...tags].sort((a, b) => {
    if (!a.lastUsedAt && !b.lastUsedAt) return 0
    if (!a.lastUsedAt) return 1
    if (!b.lastUsedAt) return -1
    return b.lastUsedAt.getTime() - a.lastUsedAt.getTime()
  })
}

export interface ResolveTagForAttachInput {
  allTags: Tag[]
  tagName: string
  now: Date
  /** 목록에 없는 이름일 때 새 태그에 붙일 임시 id */
  provisionalId: string
}

export interface ResolvedTag {
  tag: Tag
  /** 이 자리에서 새로 만든 태그인가 — 실패하면 목록에서도 지워야 한다 */
  isNew: boolean
}

/**
 * 붙일 태그를 로컬에서 정한다 — 서버에 묻지 않는다.
 *
 * 이미 아는 이름이면 그 태그를 그대로 쓰고 사용 시각만 올린다.
 * 모르는 이름이면 임시 id로 만들어 두고, 진짜 id는 나중에 갈아 끼운다.
 */
export function resolveTagForAttach({
  allTags,
  tagName,
  now,
  provisionalId,
}: ResolveTagForAttachInput): ResolvedTag | null {
  const name = normalizeTagName(tagName)
  if (!name) return null

  const existing = allTags.find((t) => normalizeTagName(t.name) === name)
  if (existing) {
    return { tag: { ...existing, lastUsedAt: now }, isNew: false }
  }

  return {
    tag: { id: provisionalId, name, createdAt: now, lastUsedAt: now },
    isNew: true,
  }
}

export interface ApplyTagAttachInput<N extends TaggedNote> {
  notes: N[]
  allTags: Tag[]
  noteId: string
  tag: Tag
}

/** 낙관적 부착 — 왕복 전에 화면 상태를 만든다 */
export function applyTagAttach<N extends TaggedNote>({
  notes,
  allTags,
  noteId,
  tag,
}: ApplyTagAttachInput<N>): TagState<N> {
  const nextNotes = notes.map((note) =>
    note.id === noteId && !note.tags.some((t) => t.id === tag.id)
      ? { ...note, tags: [...note.tags, tag] }
      : note
  )

  const known = allTags.some((t) => t.id === tag.id)
  const nextAllTags = known ? allTags.map((t) => (t.id === tag.id ? tag : t)) : [...allTags, tag]

  return { notes: nextNotes, allTags: sortTagsByLastUsed(nextAllTags) }
}

export interface ApplyTagDetachInput<N extends TaggedNote> {
  notes: N[]
  allTags: Tag[]
  noteId: string
  tagId: string
  /** 붙일 때 새로 만든 태그를 되돌리는 경우 — 태그 목록에서도 지운다 */
  dropFromAllTags?: boolean
}

/** 태그 떼기. 부착 실패를 되돌리는 롤백도 같은 전이다 */
export function applyTagDetach<N extends TaggedNote>({
  notes,
  allTags,
  noteId,
  tagId,
  dropFromAllTags = false,
}: ApplyTagDetachInput<N>): TagState<N> {
  const nextNotes = notes.map((note) =>
    note.id === noteId && note.tags.some((t) => t.id === tagId)
      ? { ...note, tags: note.tags.filter((t) => t.id !== tagId) }
      : note
  )

  return {
    notes: nextNotes,
    allTags: dropFromAllTags ? allTags.filter((t) => t.id !== tagId) : allTags,
  }
}

export interface ReconcileTagIdInput<N extends TaggedNote> {
  notes: N[]
  allTags: Tag[]
  provisionalId: string
  /** 서버가 돌려준 진짜 태그 */
  tag: Tag
}

/** 임시 id로 붙여 둔 태그를 서버가 준 진짜 태그로 갈아 끼운다 */
export function reconcileTagId<N extends TaggedNote>({
  notes,
  allTags,
  provisionalId,
  tag,
}: ReconcileTagIdInput<N>): TagState<N> {
  if (provisionalId === tag.id) return { notes, allTags }

  const nextNotes = notes.map((note) =>
    note.tags.some((t) => t.id === provisionalId)
      ? { ...note, tags: note.tags.map((t) => (t.id === provisionalId ? tag : t)) }
      : note
  )

  const replaced = allTags.some((t) => t.id === provisionalId)
  const nextAllTags = replaced
    ? allTags.map((t) => (t.id === provisionalId ? tag : t))
    : allTags.some((t) => t.id === tag.id)
      ? allTags.map((t) => (t.id === tag.id ? tag : t))
      : [...allTags, tag]

  return { notes: nextNotes, allTags: sortTagsByLastUsed(nextAllTags) }
}
