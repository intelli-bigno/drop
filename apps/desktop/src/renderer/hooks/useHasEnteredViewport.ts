import { useEffect, useState, type RefObject } from 'react'

/**
 * 이 요소가 **한 번이라도** 뷰포트 근처에 들어왔는지 (BRU-79).
 *
 * 되돌리지 않는다(sticky). 화면 밖으로 나갈 때 false로 되돌리면 그 카드의 본문이
 * 언마운트되면서 위쪽 높이가 줄고 스크롤이 튄다 — 그리고 다시 볼 때 서명 URL과
 * oEmbed를 또 받아야 한다. 늘어나기만 하면 둘 다 없다.
 *
 * `IntersectionObserver`가 없는 환경(오래된 런타임·테스트)에서는 처음부터 참이다.
 * 기능을 잃는 것보다 예전처럼 전부 마운트되는 편이 안전하다.
 */
export function useHasEnteredViewport(
  ref: RefObject<Element | null>,
  { rootMargin = '400px', enabled = true }: { rootMargin?: string; enabled?: boolean } = {}
): boolean {
  const [hasEntered, setHasEntered] = useState(() => typeof IntersectionObserver === 'undefined')

  useEffect(() => {
    // 이미 참이면 관측할 것이 없다 — sticky라 되돌아오지 않는다
    if (!enabled || hasEntered) return
    const element = ref.current
    if (!element) return

    const observer = new IntersectionObserver(
      (entries) => {
        if (entries.some((entry) => entry.isIntersecting)) {
          setHasEntered(true)
          observer.disconnect()
        }
      },
      { rootMargin }
    )
    observer.observe(element)
    return () => observer.disconnect()
  }, [ref, rootMargin, enabled, hasEntered])

  return hasEntered
}
