/**
 * 호버 힌트의 규칙 (BRU-213).
 *
 * 아이콘만 있는 버튼은 무엇인지도, 글쇠가 있는지도 알 수 없다. 브라우저 기본
 * `title` 툴팁은 **1초쯤 늦게** 뜨고 모양을 정할 수 없으며 글쇠를 알약으로
 * 보여 줄 방법이 없어서, 지금까지 `title="검색 (⌘K)"`처럼 괄호에 글쇠를 욱여넣고
 * 있었다. 그래서 설명과 글쇠를 **한 번에** 보여 주는 자체 힌트를 둔다.
 *
 * 이 파일에는 규칙만 있다 — 어디서 읽고 어디에 놓을지. 그리는 것은 HintLayer다.
 */

export interface Hint {
  label: string
  /** 없으면 null — 빈 알약을 그리지 않기 위해 빈 문자열과 구분한다. */
  keys: string | null
}

export interface HintRect {
  left: number
  top: number
  width: number
  height: number
}

export interface HintSize {
  width: number
  height: number
}

export interface HintPlacement {
  left: number
  top: number
  side: 'above' | 'below'
}

/** 앵커와 말풍선 사이 틈. */
export const HINT_GAP = 8

/** 화면 가장자리에서 남길 여백. */
export const HINT_MARGIN = 8

/**
 * 커서가 닿은 요소에서 힌트를 읽는다.
 *
 * `closest`로 올라가는 것이 핵심이다 — 버튼 안의 `<svg>`에 커서가 닿는 것이
 * 보통이고, 거기에는 표시가 없다.
 */
export function readHint(target: Element | null): Hint | null {
  const host = target?.closest?.('[data-hint]') as HTMLElement | null
  if (!host) return null

  const label = host.dataset.hint?.trim()
  if (!label) return null

  const keys = host.dataset.hintKeys?.trim()
  return { label, keys: keys ? keys : null }
}

/**
 * 말풍선을 놓을 자리. 기본은 앵커 아래 가운데이고, 아래가 모자라면 위로 뒤집는다.
 * 가로는 화면 안으로 밀어 넣는다 — 헤더 맨 오른쪽 버튼이 실제로 그 자리다.
 */
export function placeHint(
  anchor: HintRect,
  bubble: HintSize,
  viewport: HintSize
): HintPlacement {
  const below = anchor.top + anchor.height + HINT_GAP
  const fitsBelow = below + bubble.height + HINT_MARGIN <= viewport.height

  const centered = anchor.left + anchor.width / 2 - bubble.width / 2
  const maxLeft = viewport.width - bubble.width - HINT_MARGIN
  const left = Math.max(HINT_MARGIN, Math.min(centered, maxLeft))

  return fitsBelow
    ? { left, top: below, side: 'below' }
    : { left, top: anchor.top - HINT_GAP - bubble.height, side: 'above' }
}
