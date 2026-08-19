import { describe, it, expect, vi } from 'vitest'
import { createAsyncValueCache } from '../async-value-cache'

describe('createAsyncValueCache', () => {
  it('같은 키를 두 번 물어도 loader는 한 번만 돈다', async () => {
    const load = vi.fn(async (key: string) => `v:${key}`)
    const cache = createAsyncValueCache(load, { ttlMs: 1000 })

    expect(await cache.get('a')).toBe('v:a')
    expect(await cache.get('a')).toBe('v:a')
    expect(load).toHaveBeenCalledTimes(1)
  })

  it('아직 답이 오지 않은 요청에 겹쳐 물어도 loader는 한 번만 돈다', async () => {
    let resolve: (value: string) => void = () => {}
    const load = vi.fn(
      () =>
        new Promise<string>((r) => {
          resolve = r
        })
    )
    const cache = createAsyncValueCache(load, { ttlMs: 1000 })

    const first = cache.get('a')
    const second = cache.get('a')
    resolve('v:a')

    expect(await first).toBe('v:a')
    expect(await second).toBe('v:a')
    expect(load).toHaveBeenCalledTimes(1)
  })

  it('TTL이 지나면 다시 부른다', async () => {
    let clock = 0
    const load = vi.fn(async (key: string) => `v:${key}`)
    const cache = createAsyncValueCache(load, { ttlMs: 1000, now: () => clock })

    await cache.get('a')
    clock = 999
    await cache.get('a')
    expect(load).toHaveBeenCalledTimes(1)

    clock = 1001
    await cache.get('a')
    expect(load).toHaveBeenCalledTimes(2)
  })

  it('실패(null)는 캐시하지 않는다 — 다음 호출에서 다시 시도한다', async () => {
    const load = vi.fn<(key: string) => Promise<string | null>>()
    load.mockResolvedValueOnce(null).mockResolvedValueOnce('v:a')
    const cache = createAsyncValueCache(load, { ttlMs: 1000 })

    expect(await cache.get('a')).toBeNull()
    expect(await cache.get('a')).toBe('v:a')
    expect(load).toHaveBeenCalledTimes(2)
  })

  it('loader가 던져도 캐시에 남지 않는다', async () => {
    const load = vi.fn<(key: string) => Promise<string | null>>()
    load.mockRejectedValueOnce(new Error('boom')).mockResolvedValueOnce('v:a')
    const cache = createAsyncValueCache(load, { ttlMs: 1000 })

    await expect(cache.get('a')).rejects.toThrow('boom')
    expect(await cache.get('a')).toBe('v:a')
  })

  it('invalidate한 키는 다시 부른다', async () => {
    const load = vi.fn(async (key: string) => `v:${key}`)
    const cache = createAsyncValueCache(load, { ttlMs: 1000 })

    await cache.get('a')
    cache.invalidate('a')
    await cache.get('a')
    expect(load).toHaveBeenCalledTimes(2)
  })

  it('키가 다르면 서로 영향을 주지 않는다', async () => {
    const load = vi.fn(async (key: string) => `v:${key}`)
    const cache = createAsyncValueCache(load, { ttlMs: 1000 })

    expect(await cache.get('a')).toBe('v:a')
    expect(await cache.get('b')).toBe('v:b')
    expect(load).toHaveBeenCalledTimes(2)
  })

  it('maxEntries를 넘으면 가장 오래된 항목부터 버린다', async () => {
    const load = vi.fn(async (key: string) => `v:${key}`)
    const cache = createAsyncValueCache(load, { ttlMs: 10_000, maxEntries: 2 })

    await cache.get('a')
    await cache.get('b')
    await cache.get('c')
    expect(cache.size()).toBe(2)

    await cache.get('a') // 'a'는 밀려났으므로 다시 부른다
    expect(load).toHaveBeenCalledTimes(4)
  })
})
