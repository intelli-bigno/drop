// 편집 중 긴 본문은 카드가 아니라 에디터 본문이 스크롤한다 (BRU-130).
// .note-card 는 overflow:hidden 이라 카드가 커지면 하단이 잘린다.

export interface CaretScrollInput {
  currentScrollTop: number
  /** 스크롤 콘텐츠 좌표계에서 캐럿의 top */
  caretOffsetTop: number
  caretHeight: number
  /** 스크롤 컨테이너의 보이는 높이 */
  viewportHeight: number
}

export function computeCaretScrollTop({
  currentScrollTop,
  caretOffsetTop,
  caretHeight,
  viewportHeight,
}: CaretScrollInput): number {
  if (viewportHeight <= 0) return currentScrollTop

  const visibleTop = currentScrollTop
  const visibleBottom = currentScrollTop + viewportHeight
  const caretBottom = caretOffsetTop + caretHeight

  if (caretOffsetTop < visibleTop) {
    return Math.max(0, caretOffsetTop)
  }
  if (caretBottom > visibleBottom) {
    return Math.max(0, caretBottom - viewportHeight)
  }
  return currentScrollTop
}

export interface ScrollContainer {
  scrollTop: number
  clientHeight: number
}

export interface CaretBox {
  offsetTop: number
  height: number
}

/** 캐럿이 컨테이너 밖으로 나가 있으면 scrollTop을 맞춘다. */
export function applyCaretScroll(container: ScrollContainer, caret: CaretBox): void {
  const next = computeCaretScrollTop({
    currentScrollTop: container.scrollTop,
    caretOffsetTop: caret.offsetTop,
    caretHeight: caret.height,
    viewportHeight: container.clientHeight,
  })
  if (next === container.scrollTop) return
  container.scrollTop = next
}
