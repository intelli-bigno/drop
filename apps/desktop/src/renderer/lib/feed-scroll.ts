// 포커스된 노트가 뷰포트 안에 완전히 보이도록 할 목표 scrollTop을 계산한다.
//
// 이전 구현은 "가려졌는지"는 헤더 오프셋을 고려해 판단하면서, 실제 스크롤은
// scrollIntoView({ block: 'nearest' })로 했다. nearest는 오프셋을 적용하지 않고
// 컨테이너 가장자리에 붙이기만 해서, 위로 이동해도 카드가 헤더 아래에 계속 걸리고
// 첫 노트에서 최상단(0)에 도달하지 못했다.

interface FeedScrollInput {
  currentScrollTop: number
  /** 스크롤 컨테이너 기준 요소의 top (콘텐츠 좌표계) */
  elementOffsetTop: number
  elementHeight: number
  /** 스크롤 컨테이너의 보이는 높이 */
  viewportHeight: number
  /** 상단에서 가려지는 영역(헤더 등)의 높이 */
  topInset: number
}

export function computeFeedScrollTop({
  currentScrollTop,
  elementOffsetTop,
  elementHeight,
  viewportHeight,
  topInset,
}: FeedScrollInput): number {
  const visibleTop = currentScrollTop + topInset
  const visibleBottom = currentScrollTop + viewportHeight

  let target = currentScrollTop

  if (elementOffsetTop < visibleTop) {
    // 위로 가려짐 — 헤더만큼 여유를 두고 맞춘다
    target = elementOffsetTop - topInset
  } else if (elementOffsetTop + elementHeight > visibleBottom) {
    // 아래로 넘침 — 하단을 뷰포트에 맞추되, 뷰포트보다 큰 카드는 상단을 우선한다
    const alignBottom = elementOffsetTop + elementHeight - viewportHeight
    target = Math.min(alignBottom, elementOffsetTop - topInset)
  }

  // 최상단 근처면 끝까지 올린다 — 피드 상단 여백까지 보여야 "맨 위"로 느껴진다
  if (target <= topInset) return 0

  return Math.max(target, 0)
}

const SCROLLABLE_OVERFLOW = new Set(['auto', 'scroll', 'overlay'])

/**
 * 요소에서 위로 올라가며 실제로 스크롤하는 조상을 찾는다.
 *
 * 목표 scrollTop을 아무리 정확히 계산해도 엉뚱한 요소에 대입하면 아무 일도 일어나지
 * 않는다 — BRU-85가 정확히 그것이었다. 피드 래퍼(.feed)는 flex 컬럼일 뿐이고
 * overflow-y: auto를 가진 것은 자식(.feed-content)이라, 래퍼의 scrollTop은 늘 0이었다.
 * 그래서 "어느 div에 ref를 걸었나"에 기대지 않고 DOM에서 직접 찾는다.
 *
 * overflow-y 선언만으로는 부족하다 — `overflow: auto`인데 콘텐츠가 넘치지 않는 조상은
 * scrollTop이 언제나 0이라, 거기서 멈추면 BRU-85와 똑같이 아무 일도 일어나지 않는다.
 * **실제로 넘치는지**(scrollHeight > clientHeight)까지 확인하고 지나간다.
 */
export function resolveScrollContainer(element: HTMLElement | null): HTMLElement | null {
  let node = element?.parentElement ?? null

  while (node) {
    const overflowY = getComputedStyle(node).overflowY
    if (SCROLLABLE_OVERFLOW.has(overflowY) && node.scrollHeight > node.clientHeight) return node
    node = node.parentElement
  }

  return null
}

/** 포커스된 카드가 뷰포트 안에 들어오도록 스크롤 컨테이너를 움직인다. */
export function scrollFocusedNoteIntoView(element: HTMLElement, topInset: number): void {
  const container = resolveScrollContainer(element)
  if (!container) return

  const rect = element.getBoundingClientRect()
  const containerRect = container.getBoundingClientRect()

  const nextScrollTop = computeFeedScrollTop({
    currentScrollTop: container.scrollTop,
    elementOffsetTop: rect.top - containerRect.top + container.scrollTop,
    elementHeight: rect.height,
    viewportHeight: container.clientHeight,
    topInset,
  })

  if (nextScrollTop === container.scrollTop) return

  // 키보드 이동은 즉시 반영한다 — .feed-content의 scroll-behavior: smooth가
  // 걸린 채로 연타하면 위치가 밀린다.
  if (typeof container.scrollTo === 'function') {
    container.scrollTo({ top: nextScrollTop, behavior: 'instant' })
  } else {
    container.scrollTop = nextScrollTop
  }
}
