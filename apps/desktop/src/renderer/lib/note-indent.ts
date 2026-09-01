// 답글 들여쓰기 값 (BRU-190 → BRU-197).
//
// 들여쓰기는 카드를 미는 것이 아니라 **카드 안쪽 요소들의 왼쪽 패딩**에 얹는다.
// 카드가 전폭으로 남아야 그 안에 조상 레일(NoteTreeGuides)을 그릴 수 있기 때문이다.
//
// 값을 CSS 변수 하나로 내려보내는 이유: 카드 안에서 들여쓰기를 받아야 하는 것이
// 한 줄(.note-line)만이 아니다. 펼친 본문·편집기·첨부·링크 미리보기도 같은 자리에
// 서야 하는데, 각자 계산하면 한 곳이 빠졌을 때 레일이 본문을 가로지른다 —
// BRU-197이 정확히 그 증상이었다(편집기만 들여쓰기 밖에 있었다).

/** 한 단 들여쓰기 폭. NoteTreeGuides의 레일 간격과 같은 값이어야 한다. */
export const TREE_INDENT = 24

/** CSS 변수 이름 — 카드가 내려보내고 안쪽 요소들이 받아 쓴다. */
export const NOTE_INDENT_VAR = '--note-indent'

/**
 * 카드에 얹을 인라인 스타일. 들여쓸 것이 없으면 **undefined**를 돌려준다 —
 * `0px`를 굳이 심으면 DOM에 의미 없는 인라인 스타일이 남는다.
 */
export function noteIndentVars(depth: number): Record<string, string> | undefined {
  if (depth <= 0) return undefined
  return { [NOTE_INDENT_VAR]: `${depth * TREE_INDENT}px` }
}
