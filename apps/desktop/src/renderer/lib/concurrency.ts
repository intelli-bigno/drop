/**
 * 상한을 둔 병렬 실행 (BRU-80).
 *
 * 일괄 액션이 대상 노트를 직렬로 await하면 왕복 지연이 그대로 쌓인다 —
 * p50 92ms에 50건이면 5초 가까이 화면이 죽는다. 그렇다고 Promise.all로 전부 동시에
 * 쏘면 노트당 목록 재조회(loadNotes/loadArchived)까지 같이 폭발한다.
 * 그래서 한 번에 `limit`개만 떠 있게 흘려보낸다.
 *
 * 한 건이 던져도 나머지는 끝까지 간다 — 일괄 삭제가 중간에 멈추면 절반만 지워진 채로
 * 남는데, 그게 전부 실패하는 것보다 설명하기 어렵다. (개별 실패 알림은 스토어의 몫이다.)
 */
export async function mapWithConcurrency<T>(
  items: T[],
  limit: number,
  run: (item: T) => Promise<void>
): Promise<void> {
  if (items.length === 0) return

  let next = 0

  const worker = async (): Promise<void> => {
    while (next < items.length) {
      const item = items[next++]
      try {
        await run(item)
      } catch (error) {
        console.error('[concurrency] task failed', error)
      }
    }
  }

  const workers = Array.from({ length: Math.max(1, Math.min(limit, items.length)) }, worker)
  await Promise.all(workers)
}
