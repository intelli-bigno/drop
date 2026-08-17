import { describe, it, expect } from 'vitest'
import { planTagOverflow, TAG_LIST_GAP, TAG_AREA_MAX_RATIO } from '../tag-overflow'

describe('planTagOverflow', () => {
  it('should show nothing when there are no tags', () => {
    expect(planTagOverflow([], 200, 30)).toEqual({ visibleCount: 0, hiddenCount: 0 })
  })

  it('should show every tag when they all fit', () => {
    // 80 + 6 + 90 = 176 <= 200
    expect(planTagOverflow([80, 90], 200, 30)).toEqual({ visibleCount: 2, hiddenCount: 0 })
  })

  it('should show every tag when they fit exactly', () => {
    expect(planTagOverflow([80, 90], 176, 30)).toEqual({ visibleCount: 2, hiddenCount: 0 })
  })

  it('should show every tag before the available width is measured', () => {
    expect(planTagOverflow([80, 90], 0, 30)).toEqual({ visibleCount: 2, hiddenCount: 0 })
  })

  it('should collapse the overflowing tags into a badge', () => {
    // 80 + 6 + 30(badge) = 116 <= 120, adding the second tag needs 206
    expect(planTagOverflow([80, 90, 70], 120, 30)).toEqual({ visibleCount: 1, hiddenCount: 2 })
  })

  it('should count the badge width when deciding how many tags fit', () => {
    // 80 + 6 + 90 = 176 fits in 180, but 176 + 6 + 30(badge) = 212 does not
    expect(planTagOverflow([80, 90, 70], 180, 30)).toEqual({ visibleCount: 1, hiddenCount: 2 })
  })

  it('should hide every tag when not even one tag fits next to the badge', () => {
    expect(planTagOverflow([80, 90], 60, 30)).toEqual({ visibleCount: 0, hiddenCount: 2 })
  })

  it('should never leave a partially clipped tag', () => {
    const widths = [78, 102, 74, 112, 62]
    for (let available = 1; available <= 500; available++) {
      const { visibleCount, hiddenCount } = planTagOverflow(widths, available, 34)
      expect(visibleCount + hiddenCount).toBe(widths.length)
      const shown = widths.slice(0, visibleCount)
      const used =
        shown.reduce((sum, w) => sum + w, 0) +
        TAG_LIST_GAP * Math.max(0, visibleCount - 1) +
        (hiddenCount > 0 ? TAG_LIST_GAP * (visibleCount > 0 ? 1 : 0) + 34 : 0)
      if (visibleCount > 0) expect(used).toBeLessThanOrEqual(available)
    }
  })
})

describe('TAG_AREA_MAX_RATIO', () => {
  it('should cap the tag area at 40% of the row', () => {
    expect(TAG_AREA_MAX_RATIO).toBe(0.4)
  })
})
