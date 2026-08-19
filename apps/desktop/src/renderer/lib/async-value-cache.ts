// 같은 키에 대한 비동기 조회를 **한 번으로 줄이는** 작은 캐시.
//
// 왜 필요한가 (BRU-79): 노트 카드가 펼쳐질 때마다 첨부 하나당 서명 URL을 한 번씩
// 발급받는다. 전체 펼치기를 켜면 그 발급이 첨부 수만큼 동시에 나가고, j/k로 한 칸
// 넘길 때마다 방금 발급받은 URL을 버리고 또 발급받는다. 값이 바뀌지 않는 동안에는
// 한 번만 물어보면 되는 일이다.
//
// 세 가지를 한다:
//   1. TTL 안에서는 이미 받은 값을 그대로 준다
//   2. 아직 답이 오지 않은 요청에 겹쳐 물으면 **같은 Promise**를 준다 (in-flight 합류)
//   3. 실패는 캐시하지 않는다 — 실패를 붙잡아 두면 재시도가 영영 막힌다

export interface AsyncValueCacheOptions {
  /** 받아 둔 값을 몇 ms 동안 유효하다고 볼지 */
  ttlMs: number
  /** 붙잡아 둘 최대 항목 수. 넘으면 들어온 순서대로 버린다 */
  maxEntries?: number
  /** 시계 주입 — 테스트에서 시간을 앞으로 돌리기 위한 자리 */
  now?: () => number
}

export interface AsyncValueCache<V> {
  get(key: string): Promise<V | null>
  invalidate(key: string): void
  clear(): void
  size(): number
}

interface Entry<V> {
  value: V
  storedAt: number
}

const DEFAULT_MAX_ENTRIES = 500

export function createAsyncValueCache<V>(
  load: (key: string) => Promise<V | null>,
  { ttlMs, maxEntries = DEFAULT_MAX_ENTRIES, now = () => Date.now() }: AsyncValueCacheOptions
): AsyncValueCache<V> {
  // Map은 삽입 순서를 지킨다 — 가장 오래된 항목을 찾는 데 그 순서를 쓴다
  const entries = new Map<string, Entry<V>>()
  const inFlight = new Map<string, Promise<V | null>>()

  const evictIfNeeded = (): void => {
    while (entries.size > maxEntries) {
      const oldest = entries.keys().next()
      if (oldest.done) return
      entries.delete(oldest.value)
    }
  }

  return {
    async get(key) {
      const cached = entries.get(key)
      if (cached && now() - cached.storedAt <= ttlMs) return cached.value
      if (cached) entries.delete(key)

      const pending = inFlight.get(key)
      if (pending) return pending

      const request = load(key)
        .then((value) => {
          // null은 실패다 — 붙잡아 두면 다음 시도가 영영 막힌다
          if (value !== null && value !== undefined) {
            entries.set(key, { value, storedAt: now() })
            evictIfNeeded()
          }
          return value
        })
        .finally(() => {
          inFlight.delete(key)
        })

      inFlight.set(key, request)
      return request
    },

    invalidate(key) {
      entries.delete(key)
      inFlight.delete(key)
    },

    clear() {
      entries.clear()
      inFlight.clear()
    },

    size() {
      return entries.size
    },
  }
}
