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
