import { describe, it, expect, beforeEach } from 'vitest'
import { isQuitting, markQuitting, resetQuitState, shouldHideOnClose } from './quit-state'

describe('shouldHideOnClose', () => {
  it('shouldHideWindowOnMacWhenNotQuitting', () => {
    expect(shouldHideOnClose('darwin', false)).toBe(true)
  })

  it('shouldActuallyCloseOnMacWhenQuitting', () => {
    expect(shouldHideOnClose('darwin', true)).toBe(false)
  })

  it('shouldActuallyCloseOnOtherPlatforms', () => {
    expect(shouldHideOnClose('win32', false)).toBe(false)
    expect(shouldHideOnClose('linux', false)).toBe(false)
  })
})

describe('quit state', () => {
  beforeEach(() => {
    resetQuitState()
  })

  it('shouldNotBeQuittingInitially', () => {
    expect(isQuitting()).toBe(false)
  })

  it('shouldBeQuittingAfterMarkQuitting', () => {
    markQuitting()
    expect(isQuitting()).toBe(true)
  })

  it('shouldStayQuittingWhenMarkedTwice', () => {
    markQuitting()
    markQuitting()
    expect(isQuitting()).toBe(true)
  })

  // 업데이트 설치 시 Squirrel이 창을 닫아 앱을 종료시킨다.
  // markQuitting() 없이는 close 핸들러가 숨기기로 가로채 앱이 죽지 않고,
  // ShipIt이 무한 대기하며 업데이트가 적용되지 않는다 (v0.0.3에서 발생).
  it('shouldNotHideOnCloseOnceQuittingIsMarked', () => {
    expect(shouldHideOnClose('darwin', isQuitting())).toBe(true)
    markQuitting()
    expect(shouldHideOnClose('darwin', isQuitting())).toBe(false)
  })
})
