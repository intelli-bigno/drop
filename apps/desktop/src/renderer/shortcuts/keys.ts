// 단축키가 반응하는 실제 `event.key` 값의 단일 출처.
// 매처와 치트시트가 모두 여기서 파생된다 — 키를 여기에만 추가하면 양쪽에 반영된다.
// 한글 별칭은 한글 입력 상태에서도 같은 물리 키가 동작하게 하기 위한 것.

export const KEYS = {
  // 피드 탐색
  clearFocus: ['Escape'],
  focusNext: ['ArrowDown', 'j', 'ㅓ'],
  focusPrev: ['ArrowUp', 'k', 'ㅏ'],
  // 편집 진입은 `/`·`i`뿐이다 (BRU-53). Enter는 포커스만 옮기던 카드를 열지 않는다.
  openFocused: ['/', 'i', 'ㅑ'],
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

  // 템플릿 (빈 노트를 쓰는 중에만)
  insertTemplate: ['/'],

  // 잠금
  toggleLock: ['l', 'ㅣ'],

  // 도움말 — 맨 `/`는 편집 진입 키라 치트시트를 열지 않는다 (BRU-53).
  // ⌘/ 와 `?` 두 갈래이고, 수식키가 다르므로 항목도 둘로 나눈다.
  cheatSheet: ['/'],
  cheatSheetAlt: ['?'],
} as const

export type ShortcutKeyId = keyof typeof KEYS

export function matchesKey(id: ShortcutKeyId, eventKey: string): boolean {
  return (KEYS[id] as readonly string[]).includes(eventKey)
}
