/**
 * 복사했다는 것을 **말해 준다** (BRU-213).
 *
 * ⌘C로 포커스된 노트를 복사하는 길은 BRU-104부터 있었는데, 성공해도 화면이
 * 아무 말도 하지 않았다. 클립보드는 눈에 보이지 않으므로 "눌렀는데 아무 일도
 * 안 일어났다"와 구별되지 않는다 — 실제로 「클릭하고 ⌘C 누르면 복사되게
 * 해 달라」는 요청이 그렇게 왔다. 되고 있었지만 되는 줄 몰랐던 것이다.
 *
 * 실패도 마찬가지다. `navigator.clipboard.writeText`는 창이 포커스를 잃은
 * 사이에 거절될 수 있는데, 그 실패가 조용하면 성공과 완전히 같아 보인다.
 */
export type CopyAction = 'copyFocused' | 'copyFocusedReference'

export interface CopyToast {
  message: string
  variant?: 'error'
}

export function copyResultMessage(action: CopyAction, ok: boolean): CopyToast {
  if (!ok) return { message: '복사하지 못했습니다', variant: 'error' }
  return {
    message:
      action === 'copyFocusedReference' ? '참조 링크를 복사했습니다' : '노트 내용을 복사했습니다',
  }
}
