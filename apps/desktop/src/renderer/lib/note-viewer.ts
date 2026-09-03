// 포커스된 노트를 **읽기 전용**으로 펼쳐 보여주기 위한 파서 (BRU-59).
//
// 왜 직접 쓰는가 — 이 레포에는 마크다운 렌더러 의존성이 없고, 이 화면에 필요한
// 것은 "본문을 알아볼 수 있게 그리기"까지다. 완전한 CommonMark가 아니다.
//
// 이 파서의 계약은 하나뿐이다: **글자를 잃지 않는다.** 알아보지 못한 마커는
// 해석하지 않고 글자 그대로 흘려보낸다. 여기서 나온 결과는 다시 마크다운으로
// 직렬화되지 않고 화면에만 쓰이므로, 이 경로는 저장에 절대 닿지 않는다 (BRU-66).

import { extractUrls } from './url-utils'

export type NoteBlock =
  | { type: 'paragraph'; text: string }
  | { type: 'heading'; level: number; text: string }
  | { type: 'list'; ordered: boolean; items: string[] }
  | { type: 'tasks'; items: { checked: boolean; text: string }[] }
  | { type: 'quote'; text: string }
  | { type: 'code'; language: string | null; text: string }
  | { type: 'divider' }

const HEADING = /^(#{1,6})\s+(.*)$/
const BULLET = /^\s*[-*+]\s+(.*)$/
const ORDERED = /^\s*\d+\.\s+(.*)$/
const TASK = /^\s*[-*+]\s+\[([ xX])\]\s*(.*)$/
const QUOTE = /^\s*>\s?(.*)$/
const FENCE = /^\s*```(.*)$/
const DIVIDER = /^\s*(?:-{3,}|\*{3,}|_{3,})\s*$/

/** 노트 본문을 화면에 그릴 블록 목록으로 나눈다 */
export function parseNoteBlocks(content: string): NoteBlock[] {
  const lines = content.split('\n')
  const blocks: NoteBlock[] = []
  let i = 0

  while (i < lines.length) {
    const line = lines[i]

    if (line.trim() === '') {
      i += 1
      continue
    }

    // 코드 펜스가 가장 세다 — 안쪽은 무엇도 해석하지 않는다
    const fence = line.match(FENCE)
    if (fence) {
      const language = fence[1].trim() || null
      const body: string[] = []
      i += 1
      while (i < lines.length && !FENCE.test(lines[i])) {
        body.push(lines[i])
        i += 1
      }
      // 닫는 펜스가 있으면 넘긴다. 없어도 내용은 이미 다 담겼다.
      if (i < lines.length) i += 1
      blocks.push({ type: 'code', language, text: body.join('\n') })
      continue
    }

    if (DIVIDER.test(line)) {
      blocks.push({ type: 'divider' })
      i += 1
      continue
    }

    const heading = line.match(HEADING)
    if (heading) {
      blocks.push({ type: 'heading', level: heading[1].length, text: heading[2].trim() })
      i += 1
      continue
    }

    // 체크박스가 붙은 줄은 일반 불릿보다 먼저 본다
    if (TASK.test(line)) {
      const items: { checked: boolean; text: string }[] = []
      while (i < lines.length) {
        const task = lines[i].match(TASK)
        if (!task) break
        items.push({ checked: task[1].toLowerCase() === 'x', text: task[2] })
        i += 1
      }
      blocks.push({ type: 'tasks', items })
      continue
    }

    if (BULLET.test(line) || ORDERED.test(line)) {
      const ordered = !BULLET.test(line)
      const items: string[] = []
      while (i < lines.length) {
        if (TASK.test(lines[i])) break
        const match = lines[i].match(ordered ? ORDERED : BULLET)
        if (!match) break
        items.push(match[1])
        i += 1
      }
      blocks.push({ type: 'list', ordered, items })
      continue
    }

    if (QUOTE.test(line)) {
      const body: string[] = []
      while (i < lines.length) {
        const quote = lines[i].match(QUOTE)
        if (!quote) break
        body.push(quote[1])
        i += 1
      }
      blocks.push({ type: 'quote', text: body.join('\n') })
      continue
    }

    // 남은 것은 문단이다. 빈 줄이나 다른 블록이 나올 때까지 이어 붙인다 —
    // 줄바꿈은 원문에 있던 그대로 남긴다.
    const body: string[] = []
    while (i < lines.length) {
      const current = lines[i]
      if (current.trim() === '') break
      if (
        FENCE.test(current) ||
        DIVIDER.test(current) ||
        HEADING.test(current) ||
        TASK.test(current) ||
        BULLET.test(current) ||
        ORDERED.test(current) ||
        QUOTE.test(current)
      ) {
        break
      }
      body.push(current)
      i += 1
    }
    blocks.push({ type: 'paragraph', text: body.join('\n') })
  }

  return blocks
}

export type InlineSpan =
  | { type: 'text'; text: string }
  | { type: 'strong'; text: string }
  | { type: 'emphasis'; text: string }
  | { type: 'code'; text: string }
  | { type: 'link'; text: string; href: string }

const INLINE_CODE = /^`([^`]+)`/
const INLINE_STRONG = /^\*\*([^*]+)\*\*/
const INLINE_EMPHASIS = /^\*([^*\s][^*]*)\*/
const INLINE_LINK = /^\[([^\]]*)\]\(([^)\s]+)\)/

/**
 * 한 줄 안의 표시를 span으로 나눈다.
 *
 * 굵게 · 강조 · 인라인 코드 · 링크를 본다.
 *
 * **밑줄(`_`)은 강조로 보지 않는다** — `created_at_utc` 같은 평범한 글자를 표시로
 * 오인해 원문을 잘못 그리는 쪽이, 강조가 안 그려지는 쪽보다 나쁘다. 원래는 별표도
 * 같은 이유로 빼 두었는데(BRU-59), 그래서 데스크톱에서는 `*중요*`가 별표째 보이고
 * 모바일에서는 형광펜으로 칠해졌다 — 같은 노트가 앱마다 다르게 보였다.
 * BRU-213에서 **별표만** 되살린다: 위험한 것은 밑줄이지 별표가 아니었다.
 */
export function parseInlineSpans(text: string): InlineSpan[] {
  const spans: InlineSpan[] = []
  let buffer = ''
  let i = 0

  const flush = () => {
    if (buffer) {
      spans.push({ type: 'text', text: buffer })
      buffer = ''
    }
  }

  const bareUrls = new Set(extractUrls(text))

  while (i < text.length) {
    const rest = text.slice(i)

    const code = rest.match(INLINE_CODE)
    if (code) {
      flush()
      spans.push({ type: 'code', text: code[1] })
      i += code[0].length
      continue
    }

    const link = rest.match(INLINE_LINK)
    if (link) {
      flush()
      spans.push({ type: 'link', text: link[1], href: link[2] })
      i += link[0].length
      continue
    }

    // 굵게가 먼저다 — `**x**`를 강조 규칙이 먼저 물면 `*x*`와 남은 별표로 쪼개진다.
    const strong = rest.match(INLINE_STRONG)
    if (strong) {
      flush()
      spans.push({ type: 'strong', text: strong[1] })
      i += strong[0].length
      continue
    }

    const emphasis = rest.match(INLINE_EMPHASIS)
    if (emphasis) {
      flush()
      spans.push({ type: 'emphasis', text: emphasis[1] })
      i += emphasis[0].length
      continue
    }

    // 표시 없이 그냥 적힌 URL도 눌러서 열 수 있게 한다
    if (rest.startsWith('http')) {
      const bare = bareUrls.has(matchBareUrl(rest)) ? matchBareUrl(rest) : null
      if (bare) {
        flush()
        spans.push({ type: 'link', text: bare, href: bare })
        i += bare.length
        continue
      }
    }

    buffer += text[i]
    i += 1
  }

  flush()
  return spans
}

/** 커서 위치에서 시작하는 URL 후보를 잘라낸다 (뒤따르는 문장부호는 뺀다) */
function matchBareUrl(rest: string): string {
  const raw = rest.split(/[\s<>"']/)[0]
  return raw.replace(/[.,;:!?)\]]+$/, '')
}
