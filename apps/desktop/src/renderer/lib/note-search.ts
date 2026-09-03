/**
 * 노트 검색 (BRU-213).
 *
 * 예전 검색 모달은 `content`를 그대로 `includes`로 훑고, 결과의 **첫 줄 80자**를
 * 잘라 보여줬다. 그래서 세 가지가 어긋나 있었다:
 *
 *  - 태그를 화면에 보여주면서 **태그로는 못 찾았다**.
 *  - 맞은 글자가 81번째에 있으면 **왜 걸렸는지 알 수 없었다** — 앞머리만 보였다.
 *  - 스무 개까지만 그리면서 개수는 자른 뒤의 수를 적어 **"20개"라고 거짓말**을 했다.
 *
 * 여기서는 무엇이 걸렸는지(`matchesQuery`), 어디가 걸렸는지(`buildSnippet`),
 * 몇 개가 걸렸는지(`total`)를 셋 다 사실대로 돌려준다.
 */

import { toSingleLinePreview } from './note-line'

/** 한 번에 그리는 최대 개수. 이보다 많이 걸려도 `total`은 사실대로 센다. */
export const SEARCH_LIMIT = 20

/** 잘라 보여줄 글자 수. 이보다 길면 맞은 자리 언저리만 남긴다. */
const SNIPPET_WIDTH = 90

/**
 * 맞은 자리 **앞**에 남길 글자 수.
 *
 * 가운데에 두면 안 된다 — 목록 한 줄은 폭이 좁아서(한글로 스무 자 남짓) 창의
 * 한가운데는 이미 화면 밖이고, CSS 말줄임이 그 자리를 잘라 버린다. 왜 걸렸는지
 * 보여주려고 창을 옮겨 놓고 정작 맞은 글자가 안 보이면 아무 일도 안 한 것이다.
 * 앞에는 문맥을 알아볼 만큼만 남긴다.
 */
const SNIPPET_LEAD = 8

export interface SearchableNote {
  id: string
  displayId: number
  content: string
  tags: { name: string }[]
}

export interface SearchSegment {
  text: string
  /** 검색어에 맞은 토막인가 — 화면에서 형광펜이 칠해지는 자리 */
  match: boolean
}

export interface SearchResult<T> {
  hits: T[]
  /** 자르기 **전**의 개수 */
  total: number
}

/** 앞의 `#`는 태그·번호를 부르는 말버릇이라 검색에서는 벗긴다 */
function normalize(query: string): string {
  return query.trim().replace(/^#/, '').toLowerCase()
}

function matchesQuery(note: SearchableNote, normalized: string): boolean {
  if (note.content.toLowerCase().includes(normalized)) return true
  if (note.tags.some((tag) => tag.name.toLowerCase().includes(normalized))) return true
  // 번호는 **통째로** 맞아야 한다. 부분 일치를 허용하면 `14`가 142·146·1400을
  // 다 끌고 와서, 번호로 부르는 일 자체가 성립하지 않는다.
  return String(note.displayId) === normalized
}

export function searchNotes<T extends SearchableNote>(
  notes: T[],
  query: string,
  limit: number = SEARCH_LIMIT
): SearchResult<T> {
  const normalized = normalize(query)
  if (!normalized) return { hits: [], total: 0 }

  const matched = notes.filter((note) => matchesQuery(note, normalized))
  return { hits: matched.slice(0, limit), total: matched.length }
}

/**
 * 목록 한 줄에 그릴 토막들. 맞은 자리를 표시하고, 그 언저리만 잘라 온다.
 *
 * **글자를 잃지 않는다** — 토막을 도로 이으면 보여줄 글자가 그대로 나온다
 * (note-viewer.ts의 계약과 같다). 잘라낸 자리는 `…`로 남는다.
 */
export function buildSnippet(
  content: string,
  query: string,
  width: number = SNIPPET_WIDTH
): SearchSegment[] {
  const line = toSingleLinePreview(content)
  if (!line) return []

  const normalized = normalize(query)
  const haystack = line.toLowerCase()
  const first = normalized ? haystack.indexOf(normalized) : -1

  // 본문에 없는 말이면(태그·번호로 걸린 노트) 앞머리를 그대로 보여준다.
  const { text, prefixed, suffixed } = first < 0 ? head(line, width) : around(line, first, width)

  const segments: SearchSegment[] = []
  if (prefixed) segments.push({ text: '…', match: false })
  segments.push(...split(text, normalized))
  if (suffixed) segments.push({ text: '…', match: false })
  return segments
}

function head(line: string, width: number) {
  return { text: line.slice(0, width), prefixed: false, suffixed: line.length > width }
}

/** 맞은 자리가 앞쪽에 오도록 창을 연다 */
function around(line: string, at: number, width: number) {
  const start = Math.max(0, at - SNIPPET_LEAD)
  const end = Math.min(line.length, start + width)
  return {
    text: line.slice(start, end),
    prefixed: start > 0,
    suffixed: end < line.length,
  }
}

/** 맞은 토막과 아닌 토막으로 가른다 */
function split(text: string, normalized: string): SearchSegment[] {
  if (!normalized) return [{ text, match: false }]

  const segments: SearchSegment[] = []
  const haystack = text.toLowerCase()
  let cursor = 0

  while (cursor < text.length) {
    const at = haystack.indexOf(normalized, cursor)
    if (at < 0) break
    if (at > cursor) segments.push({ text: text.slice(cursor, at), match: false })
    segments.push({ text: text.slice(at, at + normalized.length), match: true })
    cursor = at + normalized.length
  }

  if (cursor < text.length) segments.push({ text: text.slice(cursor), match: false })
  return segments
}
