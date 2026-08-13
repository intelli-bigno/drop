// 노트 카드를 접을지 판단한다.
//
// 기본 노출은 2줄 — 피드를 훑을 때 한 화면에 들어오는 노트 수를 늘리는 것이 목적이다.
// 줄바꿈이 있으면 그만큼 길어지되, 3줄째부터는 접고 '더보기'로 넘긴다.

/** 접힘 상태에서 보여줄 본문 줄 수. CSS의 --note-collapsed-lines와 같은 값이어야 한다. */
export const COLLAPSED_LINE_LIMIT = 2

/** 한 줄이라도 이보다 길면 접는다 (줄바꿈 없이 긴 덤프 대응) */
const COLLAPSED_CHAR_LIMIT = 120

export function shouldTruncateNote(content: string): boolean {
  if (content === '') return false

  const lineCount = (content.match(/\n/g) || []).length + 1
  return lineCount > COLLAPSED_LINE_LIMIT || content.length > COLLAPSED_CHAR_LIMIT
}
