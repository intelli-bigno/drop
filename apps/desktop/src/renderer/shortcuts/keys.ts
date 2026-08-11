// 단축키가 반응하는 실제 `event.key` 값의 단일 출처.
// 매처와 치트시트가 모두 여기서 파생된다 — 키를 여기에만 추가하면 양쪽에 반영된다.
// 한글 별칭은 한글 입력 상태에서도 같은 물리 키가 동작하게 하기 위한 것.

export const KEYS = {
  // 피드 탐색
  clearFocus: ['Escape'],
  focusNext: ['ArrowDown', 'j', 'ㅓ'],
  focusPrev: ['ArrowUp', 'k', 'ㅏ'],
  openFocused: ['Enter'],
  replyToFocused: ['Enter'],
  createSibling: ['Enter'],

  // 피드 노트 액션
  deleteFocused: ['Delete', 'Backspace'],
  copyFocused: ['c', 'ㅊ'],
  togglePin: ['p', 'ㅔ'],
  setPriority0: ['0'],
  setPriority1: ['1'],
  setPriority2: ['2'],
  setPriority3: ['3'],

  // 전역
  createNote: ['n', 'ㅜ'],
  search: ['k', 'ㅏ'],

  // 휴지통 / 보관
  trashDelete: ['d', 'ㅇ'],
  archive: ['e', 'ㄷ'],
  restore: ['r', 'ㄱ'],

  // 태그
  openTagList: ['t', 'ㅅ'],
  openTagManagement: ['t', 'ㅅ'],

  // 잠금
  toggleLock: ['l', 'ㅣ'],

  // 도움말
  cheatSheet: ['/', '?'],
} as const

export type ShortcutKeyId = keyof typeof KEYS

export function matchesKey(id: ShortcutKeyId, eventKey: string): boolean {
  return (KEYS[id] as readonly string[]).includes(eventKey)
}
