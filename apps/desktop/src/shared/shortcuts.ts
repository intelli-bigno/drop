/**
 * 전역 퀵캡처 단축키 (BRU-84).
 *
 * Electron API를 부르지 않는 순수 모듈이다 — main·renderer 양쪽에서 같은 규칙을 쓰고,
 * 시뮬레이터도 Electron도 없이 vitest로 덮인다.
 */

/** 확정된 기본 조합: ⌥Space. macOS 기본 단축키와 충돌하지 않는다. */
export const DEFAULT_QUICK_CAPTURE_ACCELERATOR = 'Alt+Space'

/** 개발 실행이 설치본의 ⌥Space를 빼앗지 않도록 별도 조합을 쓴다. */
export const DEV_QUICK_CAPTURE_ACCELERATOR = 'Alt+Shift+Space'

/** Electron이 받는 표기 기준의 수식키 정렬 순서. */
const MODIFIER_ORDER = ['Command', 'Control', 'Alt', 'Shift'] as const
type Modifier = (typeof MODIFIER_ORDER)[number]

const MODIFIER_ALIASES: Record<string, Modifier> = {
  command: 'Command',
  cmd: 'Command',
  meta: 'Command',
  super: 'Command',
  commandorcontrol: 'Command',
  cmdorctrl: 'Command',
  control: 'Control',
  ctrl: 'Control',
  alt: 'Alt',
  option: 'Alt',
  opt: 'Alt',
  altgr: 'Alt',
  shift: 'Shift',
}

/** 이름이 있는 키의 별칭 → Electron 표기. */
const KEY_ALIASES: Record<string, string> = {
  space: 'Space',
  tab: 'Tab',
  enter: 'Return',
  return: 'Return',
  backspace: 'Backspace',
  delete: 'Delete',
  del: 'Delete',
  insert: 'Insert',
  home: 'Home',
  end: 'End',
  pageup: 'PageUp',
  pagedown: 'PageDown',
  up: 'Up',
  down: 'Down',
  left: 'Left',
  right: 'Right',
  arrowup: 'Up',
  arrowdown: 'Down',
  arrowleft: 'Left',
  arrowright: 'Right',
  plus: 'Plus',
}

/** 수식키 없이 눌리면 곤란한 키 — 전역으로 가로채면 다른 앱이 망가진다. */
const FORBIDDEN_KEYS = new Set(['Escape'])

const PUNCTUATION_KEYS = new Set(['-', '=', '[', ']', '\\', ';', "'", ',', '.', '/', '`'])

function canonicalizeKey(token: string): string | null {
  const lower = token.toLowerCase()

  if (lower in KEY_ALIASES) return KEY_ALIASES[lower]
  if (lower === 'escape' || lower === 'esc') return 'Escape'
  if (/^[a-z]$/.test(lower)) return lower.toUpperCase()
  if (/^[0-9]$/.test(lower)) return lower
  if (/^f([1-9]|1[0-9]|2[0-4])$/.test(lower)) return `F${lower.slice(1)}`
  if (PUNCTUATION_KEYS.has(token)) return token

  return null
}

/**
 * 사람이 쓴 조합 문자열을 Electron accelerator 표기로 정규화한다.
 * 수식키가 하나도 없거나, 키가 없거나 둘 이상이면 null.
 */
export function normalizeAccelerator(input: string): string | null {
  if (typeof input !== 'string') return null

  const tokens = input
    .split('+')
    .map((token) => token.trim())
    .filter((token) => token.length > 0)

  if (tokens.length === 0) return null

  const modifiers = new Set<Modifier>()
  const keys: string[] = []

  for (const token of tokens) {
    const modifier = MODIFIER_ALIASES[token.toLowerCase()]
    if (modifier) {
      modifiers.add(modifier)
      continue
    }

    const key = canonicalizeKey(token)
    if (!key) return null
    keys.push(key)
  }

  if (modifiers.size === 0) return null
  if (keys.length !== 1) return null
  if (FORBIDDEN_KEYS.has(keys[0])) return null

  const ordered = MODIFIER_ORDER.filter((modifier) => modifiers.has(modifier))
  return [...ordered, keys[0]].join('+')
}

export function isValidAccelerator(input: string): boolean {
  return normalizeAccelerator(input) !== null
}

/** macOS 관례 표기 순서 — ⌃⌥⇧⌘. */
const DARWIN_GLYPH_ORDER: Array<[Modifier, string]> = [
  ['Control', '⌃'],
  ['Alt', '⌥'],
  ['Shift', '⇧'],
  ['Command', '⌘'],
]

/** macOS 밖에서는 Electron 표기 순서(Command·Control·Alt·Shift)를 그대로 따른다. */
const OTHER_LABEL_ORDER: Array<[Modifier, string]> = [
  ['Command', 'Super'],
  ['Control', 'Ctrl'],
  ['Alt', 'Alt'],
  ['Shift', 'Shift'],
]

/** 사람이 읽는 표기로 바꾼다. 파싱에 실패하면 원문을 그대로 돌려준다. */
export function formatAccelerator(accelerator: string, platform: string = 'darwin'): string {
  const normalized = normalizeAccelerator(accelerator)
  if (!normalized) return accelerator

  const parts = normalized.split('+')
  const key = parts[parts.length - 1]
  const modifiers = new Set(parts.slice(0, -1) as Modifier[])

  if (platform === 'darwin') {
    const glyphs = DARWIN_GLYPH_ORDER.filter(([modifier]) => modifiers.has(modifier)).map(
      ([, glyph]) => glyph
    )
    return `${glyphs.join('')}${key}`
  }

  const labels = OTHER_LABEL_ORDER.filter(([modifier]) => modifiers.has(modifier)).map(
    ([, label]) => label
  )
  return [...labels, key].join('+')
}

/** 저장된 조합이 유효하면 그것을, 아니면 빌드에 맞는 기본값을 쓴다. */
export function resolveQuickCaptureAccelerator(options: {
  stored?: string | null
  isPackaged: boolean
}): string {
  const stored = options.stored ? normalizeAccelerator(options.stored) : null
  if (stored) return stored

  return options.isPackaged ? DEFAULT_QUICK_CAPTURE_ACCELERATOR : DEV_QUICK_CAPTURE_ACCELERATOR
}

/** 등록을 시도할 순서 — 사용자 지정이 실패하면 기본값으로 한 번 더 시도한다. */
export function buildRegistrationPlan(preferred: string, fallback: string): string[] {
  const plan: string[] = []

  for (const candidate of [preferred, fallback]) {
    const normalized = normalizeAccelerator(candidate)
    if (normalized && !plan.includes(normalized)) plan.push(normalized)
  }

  return plan
}

/**
 * 등록 실패를 사용자에게 알리는 문구. 조용히 삼키지 않는 것이 BRU-84의 완료 기준이다.
 */
export function describeRegistrationFailure(
  attempted: string[],
  platform: string = 'darwin'
): { title: string; message: string } {
  const rendered = attempted.map((accelerator) => formatAccelerator(accelerator, platform))
  const list = rendered.length > 0 ? rendered.join(', ') : '(없음)'

  return {
    title: '전역 단축키를 등록하지 못했습니다',
    message:
      `${list} 조합을 다른 앱이 이미 쓰고 있어 퀵캡처 전역 단축키가 등록되지 않았습니다.\n\n` +
      '메뉴 → 설정에서 다른 조합으로 바꾸거나, 해당 조합을 쓰는 앱을 종료한 뒤 다시 시도하세요.\n' +
      '메뉴바 아이콘에서 Quick Capture를 눌러 여는 것은 그대로 됩니다.',
  }
}

/**
 * 요청한 조합이 안 잡혀 기본값으로 물러섰을 때의 문구.
 *
 * "등록 실패"와 구분한다 — 단축키는 살아 있지만 사용자가 고른 것이 아니다.
 * 이걸 성공으로 뭉뚱그리면 사용자는 자기 조합이 먹는 줄 안다.
 */
export function describeFallbackRegistration(
  requested: string,
  active: string,
  platform: string = 'darwin'
): { title: string; message: string } {
  const wanted = formatAccelerator(requested, platform)
  const inUse = formatAccelerator(active, platform)

  return {
    title: '고른 단축키를 쓸 수 없습니다',
    message:
      `${wanted} 조합은 다른 앱이 이미 쓰고 있어 잡지 못했습니다.\n` +
      `지금은 기본값 ${inUse} 로 퀵캡처가 열립니다.\n\n` +
      '메뉴 → 설정 → 전역 단축키에서 다른 조합을 고르거나, 그 조합을 쓰는 앱을 종료한 뒤 다시 시도하세요.',
  }
}

/**
 * 캡처 창을 닫을 때 직전에 쓰던 앱으로 포커스를 돌려줄지.
 * macOS에서만 앱 단위 hide가 있고, 앱 안에서 연 캡처까지 숨기면 오히려 방해가 된다.
 */
export function shouldReturnFocusToPreviousApp(options: {
  platform: string
  invokedFromOtherApp: boolean
}): boolean {
  return options.platform === 'darwin' && options.invokedFromOtherApp
}

/** KeyboardEvent.code → Electron 키 표기. */
function keyFromCode(code: string): string | null {
  if (/^Key[A-Z]$/.test(code)) return code.slice(3)
  if (/^Digit[0-9]$/.test(code)) return code.slice(5)
  if (/^Numpad[0-9]$/.test(code)) return code.slice(6)
  if (/^F([1-9]|1[0-9]|2[0-4])$/.test(code)) return code

  const named: Record<string, string> = {
    Space: 'Space',
    Tab: 'Tab',
    Enter: 'Return',
    NumpadEnter: 'Return',
    Backspace: 'Backspace',
    Delete: 'Delete',
    Insert: 'Insert',
    Home: 'Home',
    End: 'End',
    PageUp: 'PageUp',
    PageDown: 'PageDown',
    ArrowUp: 'Up',
    ArrowDown: 'Down',
    ArrowLeft: 'Left',
    ArrowRight: 'Right',
    Minus: '-',
    Equal: '=',
    BracketLeft: '[',
    BracketRight: ']',
    Backslash: '\\',
    Semicolon: ';',
    Quote: "'",
    Comma: ',',
    Period: '.',
    Slash: '/',
    Backquote: '`',
  }

  return named[code] ?? null
}

export interface ShortcutKeyEvent {
  key: string
  code: string
  metaKey: boolean
  ctrlKey: boolean
  altKey: boolean
  shiftKey: boolean
}

/**
 * 키 입력 하나를 accelerator로 바꾼다.
 *
 * `event.key`가 아니라 `event.code`를 읽는다 — macOS에서 Option을 누르면 `key`가
 * 'å' 같은 합성 문자로 바뀌어 조합을 알아볼 수 없기 때문이다.
 */
export function acceleratorFromKeyEvent(event: ShortcutKeyEvent): string | null {
  const key = keyFromCode(event.code)
  if (!key) return null

  const modifiers: Modifier[] = []
  if (event.metaKey) modifiers.push('Command')
  if (event.ctrlKey) modifiers.push('Control')
  if (event.altKey) modifiers.push('Alt')
  if (event.shiftKey) modifiers.push('Shift')

  if (modifiers.length === 0) return null

  const ordered = MODIFIER_ORDER.filter((modifier) => modifiers.includes(modifier))
  return normalizeAccelerator([...ordered, key].join('+'))
}
