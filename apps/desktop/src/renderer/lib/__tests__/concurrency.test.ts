import { describe, it, expect } from 'vitest'
import { mapWithConcurrency } from '../concurrency'

const defer = () => {
  let resolve!: () => void
  const promise = new Promise<void>((r) => {
    resolve = r
  })
  return { promise, resolve }
}

describe('mapWithConcurrency', () => {
  it('shouldRunEveryItem', async () => {
    const seen: number[] = []
    await mapWithConcurrency([1, 2, 3, 4, 5], 2, async (n) => {
      seen.push(n)
    })
    expect(seen.sort()).toEqual([1, 2, 3, 4, 5])
  })

  it('shouldDoNothingForAnEmptyList', async () => {
    let calls = 0
    await mapWithConcurrency([], 4, async () => {
      calls++
    })
    expect(calls).toBe(0)
  })

  // 직렬 await이 아니어야 한다 — 상한만큼은 동시에 떠 있는다
  it('shouldRunUpToTheLimitAtOnce', async () => {
    const gates = [defer(), defer(), defer(), defer(), defer()]
    let started = 0

    const done = mapWithConcurrency([0, 1, 2, 3, 4], 3, async (index) => {
      started++
      await gates[index].promise
    })

    await Promise.resolve()
    expect(started).toBe(3)

    gates[0].resolve()
    await Promise.resolve()
    await Promise.resolve()
    expect(started).toBe(4)

    for (const gate of gates) gate.resolve()
    await done
    expect(started).toBe(5)
  })

  // 상한을 넘겨 한꺼번에 쏘지 않는다 — 목록 재조회까지 같이 폭발한다
  it('shouldNeverExceedTheLimit', async () => {
    let running = 0
    let peak = 0

    await mapWithConcurrency(Array.from({ length: 20 }, (_, i) => i), 4, async () => {
      running++
      peak = Math.max(peak, running)
      await Promise.resolve()
      running--
    })

    expect(peak).toBeLessThanOrEqual(4)
  })

  // 한 건이 실패해도 나머지는 끝까지 간다 — 일괄 삭제가 중간에 멈추면 절반만 지워진다
  it('shouldKeepGoingWhenOneItemFails', async () => {
    const done: number[] = []

    await mapWithConcurrency([1, 2, 3], 2, async (n) => {
      if (n === 2) throw new Error('boom')
      done.push(n)
    })

    expect(done.sort()).toEqual([1, 3])
  })
})
