import { KEYS, type ShortcutKeyId } from './keys'

// 치트시트에 보여줄 항목. 키는 여기에 적지 않고 KEYS에서 keyId로 참조한다 —
// 단축키를 추가하면 keys.ts 한 곳만 고치면 되고, 목록이 실제 동작과 어긋나지 않는다.

export type ShortcutScope = 'feed' | 'global' | 'trash' | 'tag' | 'note' | 'selection'

export interface ShortcutCatalogEntry {
  keyId: ShortcutKeyId
  label: string
  group: string
  scope: ShortcutScope
  /** 함께 눌러야 하는 수식키 */
  modifier?: 'primary' | 'shift' | 'primary-shift'
}

export const SHORTCUT_CATALOG: ShortcutCatalogEntry[] = [
  // 탐색
  { keyId: 'focusNext', label: '다음 노트', group: '탐색', scope: 'feed' },
  { keyId: 'focusPrev', label: '이전 노트', group: '탐색', scope: 'feed' },
  { keyId: 'openFocused', label: '편집 모드로 들어가기', group: '탐색', scope: 'feed' },
  { keyId: 'clearFocus', label: '편집 나가기 · 포커스 해제', group: '탐색', scope: 'feed' },
  { keyId: 'search', label: '검색', group: '탐색', scope: 'global', modifier: 'primary' },

  // 다중 선택 (BRU-80)
  { keyId: 'enterVisualSelection', label: '선택 모드', group: '선택', scope: 'selection' },
  {
    keyId: 'extendSelectionNext',
    label: '선택 아래로',
    group: '선택',
    scope: 'selection',
    modifier: 'shift',
  },
  {
    keyId: 'extendSelectionPrev',
    label: '선택 위로',
    group: '선택',
    scope: 'selection',
    modifier: 'shift',
  },

  // 노트 액션
  { keyId: 'createNote', label: '새 노트', group: '노트 액션', scope: 'global' },
  {
    keyId: 'createSibling',
    label: '같은 레벨에 새 노트',
    group: '노트 액션',
    scope: 'feed',
    modifier: 'primary',
  },
  {
    keyId: 'replyToFocused',
    label: '답글로 노트 추가',
    group: '노트 액션',
    scope: 'feed',
    modifier: 'shift',
  },
  { keyId: 'insertTemplate', label: '템플릿 넣기 (빈 노트에서)', group: '노트 액션', scope: 'note' },
  { keyId: 'copyFocused', label: '내용 복사', group: '노트 액션', scope: 'feed' },
  {
    keyId: 'copyFocusedReference',
    label: '참조 링크 복사 (에이전트용)',
    group: '노트 액션',
    scope: 'feed',
    modifier: 'primary-shift',
  },
  { keyId: 'togglePin', label: '상단 고정 전환', group: '노트 액션', scope: 'feed' },
  { keyId: 'deleteFocused', label: '휴지통으로', group: '노트 액션', scope: 'feed' },
  { keyId: 'toggleLock', label: '잠금 전환', group: '노트 액션', scope: 'note', modifier: 'primary' },
  { keyId: 'openComments', label: '댓글 열기', group: '노트 액션', scope: 'note', modifier: 'shift' },

  // 우선순위
  { keyId: 'setPriority0', label: '우선순위 없음', group: '우선순위', scope: 'feed' },
  { keyId: 'setPriority1', label: '우선순위 1', group: '우선순위', scope: 'feed' },
  { keyId: 'setPriority2', label: '우선순위 2', group: '우선순위', scope: 'feed' },
  { keyId: 'setPriority3', label: '우선순위 3', group: '우선순위', scope: 'feed' },

  // 정리
  { keyId: 'archive', label: '보관', group: '정리', scope: 'trash' },
  { keyId: 'trashDelete', label: '삭제', group: '정리', scope: 'trash' },
  { keyId: 'restore', label: '복원 (휴지통·보관함)', group: '정리', scope: 'trash' },
  { keyId: 'openTagList', label: '태그 추가', group: '정리', scope: 'tag' },
  {
    keyId: 'openTagManagement',
    label: '태그 관리',
    group: '정리',
    scope: 'tag',
    modifier: 'primary',
  },

  // 도움말 — 수식키가 달라 항목을 둘로 나눈다.
  // 맨 `/`는 편집 진입 키이므로 치트시트를 열지 않는다 (BRU-53).
  {
    keyId: 'cheatSheet',
    label: '단축키 보기',
    group: '도움말',
    scope: 'global',
    modifier: 'primary',
  },
  { keyId: 'cheatSheetAlt', label: '단축키 보기', group: '도움말', scope: 'global' },
]

const NAMED_KEYS: Record<string, string> = {
  ArrowDown: '↓',
  ArrowUp: '↑',
  ArrowLeft: '←',
  ArrowRight: '→',
  Escape: 'Esc',
}

export function formatKeyForDisplay(eventKey: string): string {
  if (NAMED_KEYS[eventKey]) return NAMED_KEYS[eventKey]
  // 알파벳 한 글자는 대문자로. 한글 별칭은 대문자 개념이 없어 그대로 남는다.
  if (eventKey.length === 1) return eventKey.toUpperCase()
  return eventKey
}

export function keysForEntry(entry: ShortcutCatalogEntry): string[] {
  return [...KEYS[entry.keyId]]
}

export function groupedCatalog(): { group: string; entries: ShortcutCatalogEntry[] }[] {
  const groups: { group: string; entries: ShortcutCatalogEntry[] }[] = []
  for (const entry of SHORTCUT_CATALOG) {
    const existing = groups.find((g) => g.group === entry.group)
    if (existing) existing.entries.push(entry)
    else groups.push({ group: entry.group, entries: [entry] })
  }
  return groups
}
