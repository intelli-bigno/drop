// 한 줄 카드(BRU-46)의 태그 영역 접기 규칙 (BRU-55).
//
// 태그는 한 줄이다. 폭이 모자라면 칩을 잘라서 반쪽만 보여주는 대신,
// 앞에서부터 들어가는 개수만 보여주고 나머지는 `+N` 배지로 접는다.
// 잘린 칩은 절대 남기지 않는다 — 그게 BRU-55의 증상이었다.

/** `.tag-list`의 칩 사이 간격 (index.css와 같은 값) */
export const TAG_LIST_GAP = 6

/** 태그 영역이 차지할 수 있는 줄 폭의 상한 — 태그가 많아도 본문을 이만큼만 밀어낸다 */
export const TAG_AREA_MAX_RATIO = 0.4

export interface TagOverflowLayout {
  /** 앞에서부터 몇 개를 보여줄지 */
  visibleCount: number
  /** `+N` 배지에 접힐 개수 */
  hiddenCount: number
}

/**
 * 칩 폭 목록과 가용 폭으로 표시할 태그 수를 정한다.
 *
 * @param chipWidths 태그 칩 각각의 자연 폭(px), 표시 순서대로
 * @param availableWidth 태그 영역에 허용된 폭(px). 0 이하면 "아직 재지 못했다"는 뜻이라 전부 보여준다
 * @param overflowBadgeWidth `+N` 배지의 폭(px)
 * @param gap 칩 사이 간격(px)
 */
export function planTagOverflow(
  chipWidths: number[],
  availableWidth: number,
  overflowBadgeWidth: number,
  gap: number = TAG_LIST_GAP
): TagOverflowLayout {
  const total = chipWidths.length
  if (total === 0) return { visibleCount: 0, hiddenCount: 0 }

  // 아직 폭을 재지 못한 첫 렌더 — 접지 않는다 (측정 후 다시 계산된다)
  if (!Number.isFinite(availableWidth) || availableWidth <= 0) {
    return { visibleCount: total, hiddenCount: 0 }
  }

  const naturalWidth = chipWidths.reduce((sum, w) => sum + w, 0) + gap * (total - 1)
  if (naturalWidth <= availableWidth) return { visibleCount: total, hiddenCount: 0 }

  // 접어야 한다 — 배지 자리를 남기고 앞에서부터 최대 몇 개가 들어가는지 센다
  let used = 0
  let visibleCount = 0
  for (let i = 0; i < total - 1; i++) {
    const next = used + (i === 0 ? 0 : gap) + chipWidths[i]
    if (next + gap + overflowBadgeWidth > availableWidth) break
    used = next
    visibleCount = i + 1
  }

  return { visibleCount, hiddenCount: total - visibleCount }
}
