/**
 * @vitest-environment jsdom
 */
import { describe, it, expect } from 'vitest'
import { resolveScrollContainer, scrollFocusedNoteIntoView } from '../feed-scroll'

const TOP_INSET = 60
const VIEWPORT = 400

interface FeedOptions {
  scrollTop?: number
  /** 카드의 콘텐츠 좌표계 top (스크롤과 무관한 값) */
  cardOffsetTop?: number
  cardHeight?: number
}

/**
 * 실제 DOM 구조를 그대로 흉내낸다:
 *   .feed          — flex 래퍼, 스크롤하지 않는다
 *     .feed-content — overflow-y: auto, 실제 스크롤 컨테이너
 *       .note-card
 *
 * BRU-85의 원인이 바로 이 두 층의 혼동이었다.
 */
function buildFeed({ scrollTop = 0, cardOffsetTop = 0, cardHeight = 100 }: FeedOptions = {}) {
  document.body.innerHTML = ''

  const feed = document.createElement('div')
  feed.className = 'feed'
  // .feed는 스크롤하지 않는다 — height/flex만 있고 overflow 선언이 없다
  feed.style.display = 'flex'

  const content = document.createElement('div')
  content.className = 'feed-content'
  content.style.overflowY = 'auto'

  const card = document.createElement('div')

  content.appendChild(card)
  feed.appendChild(content)
  document.body.appendChild(feed)

  Object.defineProperty(content, 'clientHeight', { value: VIEWPORT, configurable: true })
  content.scrollTop = scrollTop

  // jsdom은 레이아웃을 하지 않으므로 좌표를 직접 만든다.
  // 컨테이너는 화면 최상단에 있고, 카드는 콘텐츠 좌표에서 scrollTop만큼 밀려 보인다.
  content.getBoundingClientRect = () =>
    ({ top: 0, bottom: VIEWPORT, height: VIEWPORT }) as DOMRect
  card.getBoundingClientRect = () => {
    const top = cardOffsetTop - content.scrollTop
    return { top, bottom: top + cardHeight, height: cardHeight } as DOMRect
  }

  return { feed, content, card }
}

describe('resolveScrollContainer', () => {
  // BRU-85 회귀 방지의 핵심: 스크롤하는 것은 .feed가 아니라 .feed-content다.
  // 예전 코드는 .feed의 scrollTop을 건드려서 아무 일도 일어나지 않았다.
  it('shouldResolveTheScrollableAncestorNotTheFlexWrapper', () => {
    const { content, card } = buildFeed()
    expect(resolveScrollContainer(card)).toBe(content)
  })

  it('shouldReturnNullWhenNoAncestorScrolls', () => {
    const orphan = document.createElement('div')
    document.body.appendChild(orphan)
    expect(resolveScrollContainer(orphan)).toBeNull()
  })

  it('shouldReturnNullForNoElement', () => {
    expect(resolveScrollContainer(null)).toBeNull()
  })
})

describe('scrollFocusedNoteIntoView', () => {
  // 하단 진행 — j를 계속 눌러 포커스가 화면 아래로 나갔을 때 (BRU-85)
  it('shouldScrollDownWhenTheFocusedNoteIsBelowTheViewport', () => {
    const { content, card } = buildFeed({ scrollTop: 0, cardOffsetTop: 900, cardHeight: 100 })
    scrollFocusedNoteIntoView(card, TOP_INSET)
    // 카드 하단(1000)을 뷰포트 하단에 맞춘다
    expect(content.scrollTop).toBe(1000 - VIEWPORT)
  })

  // 상단 복귀 — k로 되돌아갈 때 (BRU-23 회귀 방지)
  it('shouldScrollBackToTheVeryTopForTheFirstNote', () => {
    const { content, card } = buildFeed({ scrollTop: 800, cardOffsetTop: 0, cardHeight: 100 })
    scrollFocusedNoteIntoView(card, TOP_INSET)
    expect(content.scrollTop).toBe(0)
  })

  it('shouldLeaveRoomForTheHeaderWhenScrollingUp', () => {
    const { content, card } = buildFeed({ scrollTop: 800, cardOffsetTop: 700, cardHeight: 100 })
    scrollFocusedNoteIntoView(card, TOP_INSET)
    expect(content.scrollTop).toBe(700 - TOP_INSET)
  })

  it('shouldNotMoveWhenTheNoteIsAlreadyFullyVisible', () => {
    const { content, card } = buildFeed({ scrollTop: 500, cardOffsetTop: 600, cardHeight: 100 })
    scrollFocusedNoteIntoView(card, TOP_INSET)
    expect(content.scrollTop).toBe(500)
  })

  it('shouldDoNothingWhenThereIsNoScrollContainer', () => {
    const orphan = document.createElement('div')
    document.body.appendChild(orphan)
    expect(() => scrollFocusedNoteIntoView(orphan, TOP_INSET)).not.toThrow()
  })
})
