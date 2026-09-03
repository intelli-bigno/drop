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
