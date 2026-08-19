// 노트 카드가 어떤 모습으로 그려지는지를 정하는 한 곳.
//
// 상태는 셋이다 (BRU-53 · BRU-59 · BRU-79):
//
//   one-line — 접힌 한 줄 미리보기. 기본값이다.
//   viewer   — 본문을 렌더링해 펼친 **읽기 전용** 표현.
//   editor   — Lexical 입력 에디터. 여기서만 본문이 저장 경로에 닿는다.
//
// 경계가 이 파일 하나에 모여 있는 것이 중요하다. BRU-66에서 "펼치기만 해도
// 직렬화가 원문을 덮어쓰는" 사고가 났고, 그 원인은 펼침과 편집이 같은 상태였기
// 때문이다. viewer는 에디터를 마운트하지 않으므로 저장이 일어날 경로 자체가
// 없다 — 원문 보존은 조건문이 아니라 구조로 지킨다.

export interface NoteCardViewInput {
  /** 피드에서 이 카드가 포커스를 받고 있는가 */
  isFocused: boolean
  /** `/`·`i`로 편집에 들어와 있는가 */
  isEditing: boolean
  /** 목록 전체 펼치기 토글이 켜져 있는가 (BRU-79) */
  expandAll?: boolean
}

export type NoteCardView = 'one-line' | 'viewer' | 'editor'

export function resolveNoteCardView({
  isFocused,
  isEditing,
  expandAll = false,
}: NoteCardViewInput): NoteCardView {
  // 편집은 포커스가 있는 카드에서만 성립한다 — 포커스를 잃으면 편집도 끝난다.
  if (isFocused && isEditing) return 'editor'
  // 포커스만 옮겨도 본문은 보인다. 단 읽기 전용이다 (BRU-59).
  if (isFocused) return 'viewer'
  // 일괄 펼치기도 viewer까지만이다 — 절대 editor로 가지 않는다 (BRU-79).
  if (expandAll) return 'viewer'
  return 'one-line'
}

/** 카드를 펼쳐 **에디터**를 마운트할지. viewer는 여기에 해당하지 않는다. */
export function isEditorOpen(input: NoteCardViewInput): boolean {
  return resolveNoteCardView(input) === 'editor'
}

/** 본문이 어떤 형태로든 펼쳐져 있는지 (viewer 또는 editor) */
export function isBodyExpanded(input: NoteCardViewInput): boolean {
  return resolveNoteCardView(input) !== 'one-line'
}
