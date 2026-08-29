// 대비비 계산 (BRU-172).
//
// MASTER.md는 "액센트 위에는 어두운 글자를 쓴다 — 흰 글자는 라이트 3.3:1로 떨어진다"를
// 실측값으로 적어 두었다. 쇼케이스는 그 숫자를 문서에서 베껴 오는 대신 화면에서 다시 잰다.
// 토큰이 바뀌면 숫자도 따라 바뀌어야 하기 때문이다.

import { describe, expect, it } from 'vitest'
import { contrastRatio, parseCssColor, wcagVerdict } from '../contrast'

describe('parseCssColor', () => {
  it('6자리 hex를 읽는다', () => {
    expect(parseCssColor('#d9730d')).toEqual({ r: 217, g: 115, b: 13, a: 1 })
  })

  it('3자리 hex를 읽는다', () => {
    expect(parseCssColor('#fff')).toEqual({ r: 255, g: 255, b: 255, a: 1 })
  })

  it('브라우저가 돌려주는 rgb() 문자열을 읽는다', () => {
    expect(parseCssColor('rgb(55, 53, 47)')).toEqual({ r: 55, g: 53, b: 47, a: 1 })
  })

  it('알파가 있는 rgba()도 읽는다 — 보더 토큰이 이 꼴이다', () => {
    expect(parseCssColor('rgba(55, 53, 47, 0.12)')).toEqual({ r: 55, g: 53, b: 47, a: 0.12 })
  })

  it('읽을 수 없는 값은 null이다 — 화면이 터지는 것보다 낫다', () => {
    expect(parseCssColor('')).toBeNull()
    expect(parseCssColor('var(--accent)')).toBeNull()
  })
})

describe('contrastRatio', () => {
  it('흰색과 검은색은 21:1이다', () => {
    expect(contrastRatio('#ffffff', '#000000')).toBeCloseTo(21, 1)
  })

  it('같은 색끼리는 1:1이다', () => {
    expect(contrastRatio('#d9730d', '#d9730d')).toBeCloseTo(1, 2)
  })

  it('순서를 바꿔도 값이 같다', () => {
    expect(contrastRatio('#37352f', '#f7f6f3')).toBeCloseTo(
      contrastRatio('#f7f6f3', '#37352f'),
      5
    )
  })

  // MASTER.md에 적힌 실측값. 여기가 어긋나면 문서와 코드 중 하나가 틀린 것이다.
  it('라이트 액센트 위의 흰 글자는 약 3.3:1이다', () => {
    expect(contrastRatio('#ffffff', '#d9730d')).toBeCloseTo(3.3, 1)
  })

  it('알파가 있는 색은 배경 위에 합성해서 잰다', () => {
    // 완전 투명한 검정을 흰 배경에 얹으면 흰색과 같아진다 → 1:1
    expect(contrastRatio('rgba(0, 0, 0, 0)', '#ffffff')).toBeCloseTo(1, 2)
  })

  // BRU-177: 라이트 모드 실측(2026-08-29)에서 세 짝이 WCAG에 미달했다.
  // 토큰(design-system/drop/tokens.json)을 고쳐 넘겼고, 여기 값이 다시 어긋나면
  // 누군가 tokens.json을 되돌렸거나 이 테스트 없이 값을 또 바꾼 것이다.
  it('BRU-177: 라이트 메타 글자 / 앱 배경은 큰 글자 기준(3:1)을 넘는다', () => {
    // --text-tertiary #8d8c89 / --bg-primary #f7f6f3 (전: #9b9a97, 2.60:1 — 실패)
    const ratio = contrastRatio('#8d8c89', '#f7f6f3')
    expect(ratio).toBeGreaterThanOrEqual(3)
    expect(wcagVerdict(ratio, { largeText: true }).passes).toBe(true)
  })

  it('BRU-177: 라이트 CTA 위 글자는 본문 기준(4.5:1)을 넘는다', () => {
    // --text-on-accent #000000 / --cta #d0460d (전: #1a1a1a / #c2410c, 3.36:1 — 실패)
    const ratio = contrastRatio('#000000', '#d0460d')
    expect(ratio).toBeGreaterThanOrEqual(4.5)
    expect(wcagVerdict(ratio).passes).toBe(true)
  })

  it('BRU-177: 라이트 위험 색 / 앱 배경은 본문 기준(4.5:1)을 넘는다', () => {
    // --danger #da2323 / --bg-primary #f7f6f3 (전: #dc2626, 4.47:1 — 0.03 차로 실패)
    const ratio = contrastRatio('#da2323', '#f7f6f3')
    expect(ratio).toBeGreaterThanOrEqual(4.5)
    expect(wcagVerdict(ratio).passes).toBe(true)
  })

  it('BRU-177: 이미 통과하던 짝은 --text-on-accent를 검정으로 낮춰도 계속 통과한다', () => {
    // 라이트/다크 액센트, 다크 CTA — 셋 다 이미 4.5:1을 넘었고 검정 글자로는 더 오른다.
    expect(contrastRatio('#000000', '#d9730d')).toBeGreaterThanOrEqual(4.5) // 라이트 accent
    expect(contrastRatio('#000000', '#e9a23b')).toBeGreaterThanOrEqual(4.5) // 다크 accent
    expect(contrastRatio('#000000', '#f97316')).toBeGreaterThanOrEqual(4.5) // 다크 cta
  })
})

describe('wcagVerdict', () => {
  it('본문은 4.5:1을 넘어야 통과다', () => {
    expect(wcagVerdict(4.6).passes).toBe(true)
    expect(wcagVerdict(4.4).passes).toBe(false)
  })

  it('큰 글자는 3:1이면 통과다', () => {
    expect(wcagVerdict(3.1, { largeText: true }).passes).toBe(true)
    expect(wcagVerdict(2.9, { largeText: true }).passes).toBe(false)
  })

  it('등급 이름을 함께 준다', () => {
    expect(wcagVerdict(7.5).level).toBe('AAA')
    expect(wcagVerdict(5).level).toBe('AA')
    expect(wcagVerdict(2).level).toBe('실패')
  })
})
