// WCAG 대비비 (BRU-172).
//
// 쇼케이스가 토큰 대비를 문서에서 베끼지 않고 화면에서 직접 재기 위한 것.
// 토큰이 바뀌면 숫자도 같이 바뀐다 — 그게 요점이다.

export interface Rgba {
  r: number
  g: number
  b: number
  a: number
}

const HEX_LONG = /^#([0-9a-f]{6})$/i
const HEX_SHORT = /^#([0-9a-f]{3})$/i
const RGB_FUNC = /^rgba?\(\s*([\d.]+)[\s,]+([\d.]+)[\s,]+([\d.]+)(?:[\s,/]+([\d.]+))?\s*\)$/i

/** hex·rgb()·rgba()를 읽는다. 못 읽으면 null — 화면이 터지는 것보다 낫다. */
export function parseCssColor(value: string): Rgba | null {
  const input = value.trim()
  if (!input) return null

  const long = HEX_LONG.exec(input)
  if (long) {
    const n = parseInt(long[1], 16)
    return { r: (n >> 16) & 255, g: (n >> 8) & 255, b: n & 255, a: 1 }
  }

  const short = HEX_SHORT.exec(input)
  if (short) {
    const [r, g, b] = short[1].split('').map((c) => parseInt(c + c, 16))
    return { r, g, b, a: 1 }
  }

  const func = RGB_FUNC.exec(input)
  if (func) {
    return {
      r: Number(func[1]),
      g: Number(func[2]),
      b: Number(func[3]),
      a: func[4] === undefined ? 1 : Number(func[4]),
    }
  }

  return null
}

/** 반투명한 색을 불투명한 배경 위에 얹은 결과. */
function composite(fg: Rgba, bg: Rgba): Rgba {
  if (fg.a >= 1) return fg
  return {
    r: fg.r * fg.a + bg.r * (1 - fg.a),
    g: fg.g * fg.a + bg.g * (1 - fg.a),
    b: fg.b * fg.a + bg.b * (1 - fg.a),
    a: 1,
  }
}

function channelLuminance(value: number): number {
  const c = value / 255
  return c <= 0.03928 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4)
}

function relativeLuminance({ r, g, b }: Rgba): number {
  return (
    0.2126 * channelLuminance(r) + 0.7152 * channelLuminance(g) + 0.0722 * channelLuminance(b)
  )
}

/**
 * 두 색의 대비비. 읽을 수 없는 값이 하나라도 있으면 0을 준다 —
 * 화면에서는 "잴 수 없음"으로 표시한다.
 */
export function contrastRatio(foreground: string, background: string): number {
  const bg = parseCssColor(background)
  const fg = parseCssColor(foreground)
  if (!bg || !fg) return 0

  const solidBg = composite(bg, { r: 255, g: 255, b: 255, a: 1 })
  const solidFg = composite(fg, solidBg)

  const lighter = Math.max(relativeLuminance(solidFg), relativeLuminance(solidBg))
  const darker = Math.min(relativeLuminance(solidFg), relativeLuminance(solidBg))

  return (lighter + 0.05) / (darker + 0.05)
}

export interface WcagVerdict {
  level: 'AAA' | 'AA' | '실패'
  passes: boolean
}

/** 본문은 4.5:1, 큰 글자(18.66px bold 또는 24px 이상)는 3:1이 기준선이다. */
export function wcagVerdict(ratio: number, options: { largeText?: boolean } = {}): WcagVerdict {
  const large = options.largeText ?? false
  const passThreshold = large ? 3 : 4.5
  const enhancedThreshold = large ? 4.5 : 7

  if (ratio >= enhancedThreshold) return { level: 'AAA', passes: true }
  if (ratio >= passThreshold) return { level: 'AA', passes: true }
  return { level: '실패', passes: false }
}
