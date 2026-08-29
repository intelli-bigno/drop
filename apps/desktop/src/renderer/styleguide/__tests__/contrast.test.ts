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
