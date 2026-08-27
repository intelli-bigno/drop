import { describe, expect, it } from 'vitest'
import {
  QUICK_CAPTURE_WINDOW_MAX_HEIGHT,
  QUICK_CAPTURE_WINDOW_MIN_HEIGHT,
  QUICK_CAPTURE_WINDOW_PADDING,
  QUICK_CAPTURE_WINDOW_WIDTH,
  calculateQuickCaptureWindowHeight,
  nextQuickCaptureBounds,
} from './quick-capture-bounds'

describe('calculateQuickCaptureWindowHeight', () => {
  const padding = QUICK_CAPTURE_WINDOW_PADDING
  const cap = QUICK_CAPTURE_WINDOW_MAX_HEIGHT

  it('첨부 없는 카드(59.4)는 최소 높이 80에 머문다', () => {
    expect(calculateQuickCaptureWindowHeight(59.4, padding, cap)).toBe(
      QUICK_CAPTURE_WINDOW_MIN_HEIGHT
    )
  })

  it('첨부 한 줄(63.2)도 아직 최소 높이 안이다', () => {
    expect(calculateQuickCaptureWindowHeight(63.2, padding, cap)).toBe(
      QUICK_CAPTURE_WINDOW_MIN_HEIGHT
    )
  })

  it('첨부 두 줄(86)이면 카드+상하 패딩으로 창이 커진다', () => {
    // 86 + 8*2 = 102
    expect(calculateQuickCaptureWindowHeight(86, padding, cap)).toBe(102)
  })

  it('패딩은 한쪽이 아니라 상하 양쪽이다', () => {
    expect(calculateQuickCaptureWindowHeight(100, 8, cap)).toBe(116)
    expect(calculateQuickCaptureWindowHeight(100, 10, cap)).toBe(120)
  })

  it('소수 카드 높이는 올림한다', () => {
    expect(calculateQuickCaptureWindowHeight(86.1, 8, cap)).toBe(103)
  })

  it('cap을 넘으면 cap에서 자른다 — 나머지는 카드 안 스크롤', () => {
    expect(calculateQuickCaptureWindowHeight(1000, padding, cap)).toBe(cap)
    expect(calculateQuickCaptureWindowHeight(cap, 0, cap)).toBe(cap)
  })

  it('cap 바로 아래는 자르지 않는다', () => {
    const cardHeight = cap - padding * 2
    expect(calculateQuickCaptureWindowHeight(cardHeight, padding, cap)).toBe(cap)
  })
})

describe('nextQuickCaptureBounds', () => {
  const current = {
    x: 100,
    y: 200,
    width: QUICK_CAPTURE_WINDOW_WIDTH,
    height: QUICK_CAPTURE_WINDOW_MIN_HEIGHT,
  }

  it('창 높이가 안 바뀌면 null이다 — 글자마다 setBounds를 부르지 않기 위해', () => {
    expect(nextQuickCaptureBounds(current, 59.4)).toBeNull()
    expect(nextQuickCaptureBounds(current, 63.2)).toBeNull()
  })

  it('카드가 커지면 높이만 늘리고 x·y·width는 그대로다 (top-stable)', () => {
    expect(nextQuickCaptureBounds(current, 86)).toEqual({
      x: 100,
      y: 200,
      width: QUICK_CAPTURE_WINDOW_WIDTH,
      height: 102,
    })
  })

  it('다시 줄어들 때도 y는 움직이지 않는다', () => {
    const tall = { ...current, height: 200 }
    expect(nextQuickCaptureBounds(tall, 59.4)).toEqual({
      x: 100,
      y: 200,
      width: QUICK_CAPTURE_WINDOW_WIDTH,
      height: QUICK_CAPTURE_WINDOW_MIN_HEIGHT,
    })
  })

  it('cap을 넘긴 카드는 창을 cap까지만 키운다', () => {
    expect(nextQuickCaptureBounds(current, 1000)).toEqual({
      x: 100,
      y: 200,
      width: QUICK_CAPTURE_WINDOW_WIDTH,
      height: QUICK_CAPTURE_WINDOW_MAX_HEIGHT,
    })
  })

  it('이미 cap이면 더 큰 카드가 와도 setBounds를 건너뛴다', () => {
    const capped = { ...current, height: QUICK_CAPTURE_WINDOW_MAX_HEIGHT }
    expect(nextQuickCaptureBounds(capped, 1000)).toBeNull()
  })
})
