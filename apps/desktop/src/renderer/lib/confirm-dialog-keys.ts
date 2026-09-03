// 확인 다이얼로그의 키 판정 (BRU-196).
//
// 파괴적 액션을 키보드 흐름 한가운데서 승낙·거절할 수 있어야 한다 — 휴지통에서
// `d`로 지우다가 확인 한 번에 손이 버튼으로 넘어가면 흐름이 끊긴다.
//
// 판정만 순수 함수로 떼어 둔다. ConfirmDialog는 React 컴포넌트라 렌더링 없이는
// 테스트할 수 없지만, "어떤 키가 무엇인가"는 렌더링과 무관하다.

import type { KeyEventLike } from '../shortcuts/types'
import { KEYS } from '../shortcuts/keys'

export type ConfirmDialogAction = 'confirm' | 'cancel'

// 키의 정본은 shortcuts/keys.ts다 (BRU-213). 여기 따로 적어 두었을 때는
// ⌘/ 치트시트가 이 둘의 존재를 몰랐다 — 실제로 되는데 목록에 없는 단축키였다.
const CONFIRM_KEYS: readonly string[] = KEYS.confirmYes
const CANCEL_KEYS: readonly string[] = KEYS.confirmNo

/**
 * 다이얼로그가 이 키를 무엇으로 볼 것인가. 우리 것이 아니면 null.
 *
 * Shift는 세지 않는다 — `shortcuts/matchers.ts`의 `isPlainKey`와 같은 판단이다.
 * ⇧Y는 `Y`로 오는데 그걸 거절해 봐야 "왜 안 먹지"가 될 뿐이고, 다이얼로그가 떠
 * 있는 동안 ⇧Y에 다른 의미를 줄 일도 없다.
 */
export function resolveConfirmDialogKey(event: KeyEventLike): ConfirmDialogAction | null {
  if (event.metaKey || event.ctrlKey || event.altKey) return null

  if (event.key === 'Escape') return 'cancel'

  const folded = event.key.toLowerCase()
  if (CONFIRM_KEYS.includes(folded)) return 'confirm'
  if (CANCEL_KEYS.includes(folded)) return 'cancel'

  return null
}

export type ConfirmDialogFocus = 'confirm' | 'cancel'

/**
 * 다이얼로그가 열릴 때 **어느 버튼이 초점을 드는가** (BRU-213).
 *
 * BRU-54는 기본 초점을 취소에 뒀다: 파괴적 버튼에 초점을 두면 Backspace와 Enter
 * 두 번에 노트가 사라진다는 이유였다. 그 판단은 **되돌릴 수 없는 것**에 대해서는
 * 그대로 옳다.
 *
 * 그런데 휴지통으로 보내는 삭제는 되돌릴 수 있다 — 휴지통에서 `r`로 복원한다.
 * 되돌릴 수 있는 일까지 두 손 걸음을 요구하면, Delete를 누르고 Enter를 치는 손이
 * 매번 헛돈다. 그래서 규칙을 뒤집지 않고 **조건을 붙인다**.
 *
 * 기본값은 안전한 쪽이다 — 앞으로 생길 다이얼로그가 아무 말 없이 파괴적 기본값을
 * 갖지 않게 한다. 되돌릴 수 있다는 것은 부르는 쪽이 **명시해야** 하는 사실이다.
 */
export function initialFocus({ reversible }: { reversible?: boolean }): ConfirmDialogFocus {
  return reversible ? 'confirm' : 'cancel'
}
