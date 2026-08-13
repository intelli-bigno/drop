import { describe, it, expect } from 'vitest'
import { computeFeedScrollTop } from '../feed-scroll'

const base = {
  currentScrollTop: 500,
  elementOffsetTop: 600,
  elementHeight: 100,
  viewportHeight: 400,
  topInset: 60,
}

describe('computeFeedScrollTop', () => {
  it('shouldNotScrollWhenElementIsFullyVisible', () => {
    // 600~700 이 500+60=560 ~ 900 안에 완전히 들어온다
    expect(computeFeedScrollTop(base)).toBe(500)
  })

  it('shouldScrollUpAndLeaveRoomForTheHeader', () => {
    // 요소가 헤더 아래에 걸림 (offsetTop 520 < scrollTop 500 + inset 60)
    expect(computeFeedScrollTop({ ...base, elementOffsetTop: 520 })).toBe(520 - 60)
  })

  it('shouldScrollDownJustEnoughToRevealTheBottom', () => {
    // 요소 하단 1000 > 뷰포트 하단 900
    expect(computeFeedScrollTop({ ...base, elementOffsetTop: 900 })).toBe(900 + 100 - 400)
  })

  // "끝까지 위로 안 올라간다"의 직접 해소: 최상단 근처면 0으로 스냅
  it('shouldSnapToTopWhenTargetIsWithinTheInset', () => {
    expect(
      computeFeedScrollTop({ ...base, currentScrollTop: 80, elementOffsetTop: 100 })
    ).toBe(0)
  })

  it('shouldSnapToTopForTheFirstElement', () => {
    expect(
      computeFeedScrollTop({ ...base, currentScrollTop: 200, elementOffsetTop: 0 })
    ).toBe(0)
  })

  it('shouldNeverReturnNegativeScrollTop', () => {
    expect(
      computeFeedScrollTop({ ...base, currentScrollTop: 10, elementOffsetTop: 5 })
    ).toBe(0)
  })

  it('shouldPreferShowingTheTopWhenElementIsTallerThanViewport', () => {
    // 뷰포트보다 큰 카드는 상단을 보여주는 쪽이 읽기 흐름에 맞다
    const result = computeFeedScrollTop({
      ...base,
      elementOffsetTop: 1000,
      elementHeight: 900,
      currentScrollTop: 500,
    })
    expect(result).toBe(1000 - 60)
  })
})
