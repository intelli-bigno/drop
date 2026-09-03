import { useEffect, useLayoutEffect, useRef, useState } from 'react'
import { createPortal } from 'react-dom'
import { placeHint, readHint, type Hint, type HintRect } from '../lib/hint'

/** 손이 스칠 때마다 뜨지 않게 두는 뜸. 브라우저 기본(약 1초)보다는 훨씬 빠르다. */
const OPEN_DELAY = 320

/**
 * 앱에 **하나만** 서는 힌트 층 (BRU-213).
 *
 * 버튼마다 컴포넌트를 감싸지 않는 이유는 둘이다.
 * ① 노트 행의 액션 툴바는 `overflow: hidden`인 카드 안에 있어서, 그 안에서 그린
 *    말풍선은 잘린다. 포털로 문서 맨 위에 그리면 어디서든 온전히 뜬다.
 * ② 감싸는 방식은 버튼마다 마크업이 한 겹씩 늘어 레이아웃을 건드린다. 여기서는
 *    `data-hint` 한 줄만 붙이면 된다.
 *
 * 키보드로 초점이 닿을 때도 뜬다 — 마우스에만 열리면 글쇠를 쓰는 사람에게는
 * 힌트가 아예 없는 것과 같다.
 */
export function HintLayer() {
  const [hint, setHint] = useState<Hint | null>(null)
  const [anchor, setAnchor] = useState<HintRect | null>(null)
  const [style, setStyle] = useState<{ left: number; top: number } | null>(null)
  const bubbleRef = useRef<HTMLDivElement>(null)
  const timer = useRef<ReturnType<typeof setTimeout>>()

  useEffect(() => {
    const clear = () => {
      clearTimeout(timer.current)
      setHint(null)
      setAnchor(null)
      setStyle(null)
    }

    const show = (target: Element | null, immediate: boolean) => {
      const next = readHint(target)
      if (!next) return clear()

      const host = (target as HTMLElement).closest('[data-hint]') as HTMLElement
      clearTimeout(timer.current)
      const open = () => {
        const rect = host.getBoundingClientRect()
        setAnchor({ left: rect.left, top: rect.top, width: rect.width, height: rect.height })
        setHint(next)
      }
      if (immediate) open()
      else timer.current = setTimeout(open, OPEN_DELAY)
    }

    const onOver = (event: MouseEvent) => show(event.target as Element, false)
    // 초점은 눌러서 옮긴 것이라 이미 의도가 있다 — 기다리지 않는다.
    const onFocus = (event: FocusEvent) => show(event.target as Element, true)

    document.addEventListener('mouseover', onOver)
    document.addEventListener('mouseout', clear)
    document.addEventListener('focusin', onFocus)
    document.addEventListener('focusout', clear)
    // 누르는 순간 사라진다 — 눌린 뒤에도 남아 있으면 방금 한 일을 가린다.
    document.addEventListener('mousedown', clear)
    document.addEventListener('keydown', clear)
    window.addEventListener('scroll', clear, true)

    return () => {
      clearTimeout(timer.current)
      document.removeEventListener('mouseover', onOver)
      document.removeEventListener('mouseout', clear)
      document.removeEventListener('focusin', onFocus)
      document.removeEventListener('focusout', clear)
      document.removeEventListener('mousedown', clear)
      document.removeEventListener('keydown', clear)
      window.removeEventListener('scroll', clear, true)
    }
  }, [])

  // 말풍선을 그린 **뒤에** 그 크기로 자리를 정한다 — 글자 길이를 미리 알 수 없다.
  // 그리기 전에는 화면 밖에 두어 한 프레임짜리 깜빡임을 막는다.
  useLayoutEffect(() => {
    if (!hint || !anchor || !bubbleRef.current) return
    const box = bubbleRef.current.getBoundingClientRect()
    setStyle(
      placeHint(anchor, { width: box.width, height: box.height }, {
        width: window.innerWidth,
        height: window.innerHeight,
      })
    )
  }, [hint, anchor])

  if (!hint) return null

  return createPortal(
    <div
      ref={bubbleRef}
      className="hint"
      role="tooltip"
      style={style ? { left: style.left, top: style.top } : { left: -9999, top: -9999 }}
    >
      <span className="hint-label">{hint.label}</span>
      {hint.keys && <kbd className="hint-keys">{hint.keys}</kbd>}
    </div>,
    document.body
  )
}
