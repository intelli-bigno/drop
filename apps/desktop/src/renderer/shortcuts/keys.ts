// 단축키가 반응하는 실제 `event.key` 값의 단일 출처.
// 매처와 치트시트가 모두 여기서 파생된다 — 키를 여기에만 추가하면 양쪽에 반영된다.
// 한글 별칭은 한글 입력 상태에서도 같은 물리 키가 동작하게 하기 위한 것.

export const KEYS = {
  // 피드 탐색
  clearFocus: ['Escape'],
  focusNext: ['ArrowDown', 'j', 'ㅓ'],
  focusPrev: ['ArrowUp', 'k', 'ㅏ'],
  // 편집 진입은 `i` 하나다. `/`는 BRU-213에서 액션 줄로 넘어갔다 —
  // 두 글쇠가 같은 일을 하는 것보다, 자주 쓰는 다른 일 하나를 더 얻는 쪽이 낫다.
  openFocused: ['i', 'ㅑ'],
  // 맨 Enter로 펼쳐 읽는다 (BRU-213). BRU-53에서 Enter가 **편집을** 열지 않게 한
  // 것은 그대로다 — 읽기 위해 펼치는 것과 고치려고 들어가는 것은 다른 층이다.
  expandFocused: ['Enter'],
  replyToFocused: ['Enter'],
  createSibling: ['Enter'],
  // 포커스된 줄의 액션 줄을 글쇠로 연다 (BRU-213). 마우스를 올렸을 때 뜨는 그
  // 툴바를 그대로 띄우고, 방향키로 고른다 — 손을 옮기지 않고 같은 것을 쓴다.
  openActions: ['/'],
  // 미리보기 패널 (BRU-179). Finder의 Quick Look과 같은 자리다.
  // 편집 중에는 글자이고 선택 모드에서는 선택의 자리라 그 층에서 비켜선다.
  togglePreview: [' '],

  // 다중 선택 (BRU-80). Shift+J/K는 영문에서는 대문자로, 한글 입력 상태에서는
  // ㅓ/ㅏ 그대로 찍히므로 둘 다 별칭으로 둔다.
  enterVisualSelection: ['v', 'ㅍ'],
  extendSelectionNext: ['J', 'ㅓ'],
  extendSelectionPrev: ['K', 'ㅏ'],

  // 피드 노트 액션
  deleteFocused: ['Delete', 'Backspace'],
  copyFocused: ['c', 'ㅊ'],
  // 참조 링크 복사 — ⌘⇧C (BRU-104). Shift가 눌리면 `c`가 `C`로 오므로 대문자로 적는다.
  // 한글 입력 상태에서는 Shift+ㅊ가 `ㅊ` 그대로 찍힌다.
  copyFocusedReference: ['C', 'ㅊ'],
  togglePin: ['p', 'ㅔ'],
  setPriority0: ['0'],
  setPriority1: ['1'],
  setPriority2: ['2'],
  setPriority3: ['3'],

  // 전역
  createNote: ['n', 'ㅜ'],
  // ⌘K와 ⌘O 둘 다 (BRU-213). K는 명령 팔레트 계열의 관습이고, O는 "열기"의
  // 관습이다 — 손이 어느 쪽에 익었든 같은 자리가 열려야 한다.
  // 한 동작에 글쇠가 둘일 뿐이라 항목은 하나다(치트시트에 「검색」이 두 줄로 서면 안 된다).
  search: ['k', 'ㅏ', 'o', 'ㅐ'],

  // 휴지통 / 보관
  trashDelete: ['d', 'ㅇ'],
  archive: ['e', 'ㄷ'],
  restore: ['r', 'ㄱ'],

  // 태그
  openTagList: ['t', 'ㅅ'],
  openTagManagement: ['t', 'ㅅ'],

  // 템플릿 (빈 노트를 쓰는 중에만)
  insertTemplate: ['/'],

  // 편집 중 Enter는 줄바꿈이다 (BRU-134). 피드의 Enter(답글/형제)와 다른 층.
  insertNewline: ['Enter'],

  // 댓글 — Shift+C. 맨 `c`는 내용 복사, ⌘C는 OS 복사라 남는 자리가 Shift뿐이다 (BRU-63).
  // 한글 입력 상태에서 Shift+ㅊ는 `ㅊ` 그대로 찍히므로 별칭으로 함께 둔다.
  openComments: ['C', 'ㅊ'],

  // 잠금
  toggleLock: ['l', 'ㅣ'],

  // 확인 다이얼로그의 승낙·거절 (BRU-196). 파괴적 액션을 키보드 흐름 한가운데서
  // 끝낼 수 있어야 한다. 두벌식에서 y=ㅛ, n=ㅜ다.
  // BRU-213에서 이 표로 옮겼다 — 그전에는 lib/confirm-dialog-keys.ts 안에만 있어서
  // ⌘/ 치트시트가 이 둘을 몰랐다.
  confirmYes: ['y', 'ㅛ'],
  confirmNo: ['n', 'ㅜ'],

  // 보기 — ⌘⇧D로 라이트↔다크 (BRU-213). 맨 `d`는 휴지통의 삭제이고 ⌘D는
  // 비어 있지만, 지우는 키와 한 겹 차이로 두면 손이 미끄러진다. ⇧를 더해 뗀다.
  // Shift가 눌리면 `d`는 `D`로, 한글 입력 상태에서는 `ㅇ` 그대로 온다.
  toggleTheme: ['D', 'ㅇ'],

  // 도움말 — 맨 `/`는 편집 진입 키라 치트시트를 열지 않는다 (BRU-53).
  // ⌘/ 와 `?` 두 갈래이고, 수식키가 다르므로 항목도 둘로 나눈다.
  cheatSheet: ['/'],
  cheatSheetAlt: ['?'],
} as const

export type ShortcutKeyId = keyof typeof KEYS

export function matchesKey(id: ShortcutKeyId, eventKey: string): boolean {
  return (KEYS[id] as readonly string[]).includes(eventKey)
}
