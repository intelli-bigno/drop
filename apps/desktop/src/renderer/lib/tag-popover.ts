// 편집 종료 시점 태그 팝오버(BRU-44)의 순수 규칙.
//
// 팝오버는 "지금 정하라"는 다이얼로그가 아니라 넘겨도 되는 제안이다.
// 그래서 여는 조건도 보수적이다 — 실제로 뭔가 적고 나온 노트에서만 뜬다.

import type { Tag } from '@drop/shared'

/** 태그 이름의 정규형 — 저장소가 소문자로 저장하므로 비교도 소문자로 한다 */
export function normalizeTagName(name: string): string {
  return name.trim().toLowerCase()
}

export interface TagSuggestion {
  id: string
  name: string
  /** 이 노트에 이미 붙어 있는 태그인가 — 목록에서 체크로 보이고 다시 누르면 뗀다 */
  attached: boolean
}

export interface RankTagSuggestionsInput {
  allTags: Tag[]
  /** 이 노트에 이미 붙은 태그 이름들 */
  attachedTagNames: string[]
  /** 태그 id → 이 태그가 붙은 노트 수 */
  usageCounts?: Record<string, number>
  query: string
  limit?: number
}

const DEFAULT_LIMIT = 8

/**
 * 팝오버에 보여줄 태그 목록.
 *
 * 1. 입력이 있으면 부분 일치(대소문자 무시)로 좁힌다 — 앞부분 일치가 먼저다
 * 2. 최근에 쓴 것 먼저 (한 번도 안 쓴 태그는 맨 뒤)
 * 3. 최근 사용 시각이 같으면 자주 쓴 것 먼저
 * 4. 그래도 같으면 이름 순
 *
 * 이미 붙은 태그도 빼지 않는다 — 다시 눌러 떼야 하기 때문이다.
 */
export function rankTagSuggestions({
  allTags,
  attachedTagNames,
  usageCounts = {},
  query,
  limit = DEFAULT_LIMIT,
}: RankTagSuggestionsInput): TagSuggestion[] {
  const normalizedQuery = normalizeTagName(query)
  const attached = new Set(attachedTagNames.map(normalizeTagName))

  const matched = allTags.filter(
    (tag) => !normalizedQuery || normalizeTagName(tag.name).includes(normalizedQuery)
  )

  const prefixRank = (tag: Tag) =>
    normalizedQuery && normalizeTagName(tag.name).startsWith(normalizedQuery) ? 0 : 1

  const sorted = [...matched].sort((a, b) => {
    const byPrefix = prefixRank(a) - prefixRank(b)
    if (byPrefix !== 0) return byPrefix

    const aUsed = a.lastUsedAt?.getTime() ?? null
    const bUsed = b.lastUsedAt?.getTime() ?? null
    if (aUsed !== bUsed) {
      if (aUsed === null) return 1
      if (bUsed === null) return -1
      return bUsed - aUsed
    }

    const byUsage = (usageCounts[b.id] ?? 0) - (usageCounts[a.id] ?? 0)
    if (byUsage !== 0) return byUsage

    return a.name.localeCompare(b.name)
  })

  return sorted.slice(0, limit).map((tag) => ({
    id: tag.id,
    name: tag.name,
    attached: attached.has(normalizeTagName(tag.name)),
  }))
}

export interface ShouldShowCreateOptionInput {
  allTags: Tag[]
  query: string
}

/** 입력한 이름이 아직 없는 태그면 그 자리에서 만들 수 있게 한다 */
export function shouldShowCreateOption({
  allTags,
  query,
}: ShouldShowCreateOptionInput): boolean {
  const normalized = normalizeTagName(query)
  if (!normalized) return false
  return !allTags.some((tag) => normalizeTagName(tag.name) === normalized)
}

/**
 * ↑/↓ 선택 이동. 목록 끝에서 넘어가지 않는다 —
 * 목록이 줄어들었을 때 넘친 인덱스를 되돌리는 용도로도 쓴다(delta 0).
 */
export function moveSelection(index: number, delta: number, total: number): number {
  if (total <= 0) return 0
  return Math.min(Math.max(index + delta, 0), total - 1)
}

export interface ShouldOpenTagPopoverInput {
  /** 이번 편집 세션에서 본문이 실제로 바뀌었는가 */
  contentChanged: boolean
  content: string
  isLocked: boolean
}

/**
 * 편집에서 빠져나올 때 팝오버를 열지 말지.
 *
 * 카드를 열어보기만 하고 나온 경우·빈 노트·잠긴 노트에서는 열지 않는다.
 * 훑어보는 동작마다 팝오버가 튀어나오면 "넘기는 것에 벌이 없다"가 깨진다.
 */
export function shouldOpenTagPopoverOnEditEnd({
  contentChanged,
  content,
  isLocked,
}: ShouldOpenTagPopoverInput): boolean {
  if (isLocked) return false
  if (!contentChanged) return false
  return content.trim().length > 0
}
