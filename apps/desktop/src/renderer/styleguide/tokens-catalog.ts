// 쇼케이스가 훑을 토큰 목록 (BRU-172).
//
// 값은 여기 적지 않는다 — 이름만 적고 실제 값은 화면에서 getComputedStyle로 읽는다.
// 값을 여기 복제하면 tokens.json과 갈라지고, 그 순간 쇼케이스가 거짓말을 시작한다.
// 정본은 design-system/drop/tokens.json이고 tokens.css는 그 생성물이다.

export interface TokenGroup {
  title: string
  note?: string
  tokens: string[]
}

export const COLOR_GROUPS: TokenGroup[] = [
  {
    title: '표면',
    note: '아래로 갈수록 위에 얹히는 면이다.',
    tokens: ['--bg-primary', '--bg-secondary', '--bg-card', '--bg-elevated', '--bg-tertiary', '--bg-hover'],
  },
  {
    title: '액센트',
    note: '포커스·선택·핀은 accent, 주요 행동 버튼은 cta.',
    tokens: ['--accent', '--accent-hover', '--accent-subtle', '--cta', '--cta-hover', '--text-on-accent'],
  },
  {
    title: '글자',
    note: 'tertiary·muted는 메타 전용 — 본문에 쓰지 않는다.',
    tokens: ['--text-primary', '--text-secondary', '--text-tertiary', '--text-muted'],
  },
  {
    title: '경계',
    tokens: ['--border-color', '--border-subtle', '--border-focus'],
  },
  {
    title: '의미색',
    note: '액센트와 다른 축이다 — 상태를 뜻하지 브랜드를 뜻하지 않는다.',
    tokens: ['--success', '--warning', '--danger', '--danger-hover'],
  },
  {
    title: '우선순위',
    tokens: ['--priority-low', '--priority-medium', '--priority-high'],
  },
  {
    title: '외부 브랜드',
    note: '남의 브랜드 색이라 두 모드에서 같다.',
    tokens: ['--brand-instagram', '--brand-youtube'],
  },
]

export const SPACE_TOKENS = [
  '--space-1',
  '--space-2',
  '--space-3',
  '--space-4',
  '--space-5',
  '--space-6',
  '--space-7',
  '--space-8',
]

export const RADIUS_TOKENS = ['--radius-sm', '--radius-md', '--radius-lg', '--radius-xl']

export const TEXT_TOKENS = [
  '--text-xs',
  '--text-sm',
  '--text-base',
  '--text-lg',
  '--text-xl',
  '--text-2xl',
  // 로그인 워드마크 전용 (BRU-193). 데스크톱은 아직 안 쓰지만 정본에 있는 값은
  // 여기 다 보여야 한다 — 목록에서 빠지면 토큰이 조용히 사라진 것처럼 보인다.
  '--text-3xl',
]

export const SHADOW_TOKENS = ['--shadow-sm', '--shadow-md', '--shadow-lg']

export const TRANSITION_TOKENS = ['--transition-fast', '--transition-normal', '--transition-slow']

export const FONT_TOKENS = ['--font-sans', '--font-mono']

/**
 * 대비를 재야 하는 짝. MASTER.md가 숫자를 적어 둔 자리와 같다.
 * `large`는 큰 글자 기준(3:1)을 적용할 자리.
 */
export interface ContrastPair {
  label: string
  foreground: string
  background: string
  large?: boolean
}

export const CONTRAST_PAIRS: ContrastPair[] = [
  { label: '본문 / 앱 배경', foreground: '--text-primary', background: '--bg-primary' },
  { label: '본문 / 카드', foreground: '--text-primary', background: '--bg-card' },
  { label: '보조 글자 / 앱 배경', foreground: '--text-secondary', background: '--bg-primary' },
  { label: '메타 글자 / 앱 배경', foreground: '--text-tertiary', background: '--bg-primary', large: true },
  { label: '액센트 위 글자', foreground: '--text-on-accent', background: '--accent' },
  { label: 'CTA 위 글자', foreground: '--text-on-accent', background: '--cta' },
  { label: '액센트 위 흰 글자 (금지 사례)', foreground: '#ffffff', background: '--accent' },
  { label: '위험 색 / 앱 배경', foreground: '--danger', background: '--bg-primary' },
]
