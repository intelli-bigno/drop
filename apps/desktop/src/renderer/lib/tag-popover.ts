// 태그 팝오버의 순수 규칙 — 목록을 어떻게 고르고 정렬하고 훑는가.
//
// 팝오버를 **언제 여는가**는 여기 없다. BRU-44가 "편집 종료 시점"이라는
// 답을 넣었었다 — 팝오버는 다이얼로그가 아니라 넘겨도 되는 제안이라는
// 설계였고, 그래서 여는 조건도 보수적이었다(실제로 뭔가 적고 나온 노트에서만).
// 그 판단은 BRU-110에서 뒤집혔다. 실사용에서 제안은 제안으로 읽히지 않았고
// 한 줄 캡처마다 튀어나오는 마찰이었다 — 캡처 속도가 이 앱의 존재 이유라
// 제안 쪽이 졌다. `shouldOpenTagPopoverOnEditEnd()`는 그때 삭제됐다.
//
// 지금 팝오버를 여는 길은 `t`(명시적 진입) 하나다. 자동으로 여는 규칙을
// 여기 다시 만들기 전에 위 두 이슈를 먼저 읽을 것.

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
