import { describe, expect, it } from 'vitest'
import { resolveAppRoute } from '../app-route'

describe('resolveAppRoute', () => {
  it('빈 hash는 main 화면으로 판정한다', () => {
    expect(resolveAppRoute('')).toBe('main')
  })

  it('#만 있는 hash도 main 화면으로 판정한다', () => {
    expect(resolveAppRoute('#')).toBe('main')
  })

  it('#quick-capture는 quick-capture 화면으로 판정한다', () => {
    expect(resolveAppRoute('#quick-capture')).toBe('quick-capture')
  })

  it('#styleguide는 styleguide 화면으로 판정한다', () => {
    expect(resolveAppRoute('#styleguide')).toBe('styleguide')
  })

  it('#styleguide/layouts처럼 하위 경로가 붙어도 styleguide 화면으로 판정한다', () => {
    expect(resolveAppRoute('#styleguide/layouts')).toBe('styleguide')
  })

  it('알 수 없는 hash는 main 화면으로 판정한다', () => {
    expect(resolveAppRoute('#unknown-route')).toBe('main')
  })
})
