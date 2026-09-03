/**
 * 편집기의 ⌘K — 링크 걸기 (BRU-213).
 *
 * ⌘K는 원래 검색과 나눠 쓰고 있었는데, 글을 쓰는 자리에서 ⌘K는 어느 앱에서나
 * 「링크 걸기」다(Word · Google Docs · Notion · Slack 입력창). 그래서 검색은
 * ⌘O 하나로 모으고 ⌘K를 편집기에 돌려준다.
 *
 * **주소를 묻는 창을 새로 만들지 않는다.** 실제 손버릇은 「주소를 복사하고 →
 * 글자를 골라 → ⌘K」이고, 그 흐름에는 물어볼 것이 없다. 클립보드에 주소가 없고
 * 고른 글자도 주소가 아니면 **아무것도 하지 않는다** — 빈 링크를 만들어 두면
 * 나중에 그것을 찾아 지워야 하고, 그게 안 걸린 것보다 나쁘다.
 */

import { extractUrls } from './url-utils'

export interface LinkShortcutInput {
  /** 지금 고른 글자 */
  selectedText: string
  /** 클립보드에 담긴 글 */
  clipboardText: string
  /** 고른 자리가 이미 링크인가 */
  isLink: boolean
}

export type LinkAction =
  | { type: 'unlink' }
  /** 고른 글자에 이 주소를 건다 */
  | { type: 'link'; url: string }
  /** 고른 글자가 없다 — 이 주소를 글자로 넣고 링크로 만든다 */
  | { type: 'insert'; url: string }
  | { type: 'none' }

/** `www.`로 시작하는 주소에 스킴을 붙인다 — 없으면 앱 안의 상대 경로로 열린다 */
const BARE_WWW = /^www\.[^\s]+$/i

function firstUrl(text: string): string | null {
  const found = extractUrls(text)
  if (found.length > 0) return found[0]

  const trimmed = text.trim()
  return BARE_WWW.test(trimmed) ? `https://${trimmed}` : null
}

export function resolveLinkAction({
  selectedText,
  clipboardText,
  isLink,
}: LinkShortcutInput): LinkAction {
  // 켜고 끄는 글쇠다 — 이미 링크면 푸는 것이 ⌘K의 뜻이다.
  if (isLink) return { type: 'unlink' }

  // 고른 글자가 그 자체로 주소면 그것으로 건다 — 붙여넣을 것을 따로 찾을 이유가 없다.
  // **전체**가 주소일 때만이다. 글 속에 섞인 주소까지 끌어다 쓰면 고른 글자와
  // 걸리는 주소가 어긋난다("자세한 건 https://a.com 참고"를 골랐을 때).
  const selection = selectedText.trim()
  const selectionUrl = firstUrl(selection)
  if (selectionUrl && (selection === selectionUrl || `https://${selection}` === selectionUrl)) {
    return { type: 'link', url: selectionUrl }
  }

  const fromClipboard = firstUrl(clipboardText)
  if (!fromClipboard) return { type: 'none' }

  return selectedText ? { type: 'link', url: fromClipboard } : { type: 'insert', url: fromClipboard }
}

/**
 * 사람이 입력줄에 적어 넣은 것을 실제로 걸 주소로 다듬는다.
 *
 * 스킴이 없으면 붙인다 — 없으면 앱 안의 상대 경로로 열려서, 눌러도 아무 데도
 * 안 간다. 주소로 볼 수 없는 것은 `null`이고, 그때는 걸지 않는다.
 */
export function normalizeLinkInput(raw: string): string | null {
  const trimmed = raw.trim()
  if (!trimmed) return null
  if (/\s/.test(trimmed)) return firstUrl(trimmed)
  if (/^[a-z][a-z0-9+.-]*:/i.test(trimmed)) return trimmed
  // 점이 없으면 도메인이 아니다 — "회의록" 같은 말이 링크가 되면 안 된다.
  if (!trimmed.includes('.')) return null
  return `https://${trimmed}`
}
