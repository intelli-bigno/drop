// 노트 카드가 펼쳐져 있는지(= Lexical 에디터가 마운트되는지)를 정하는 한 곳.
// 카드 안에 흩어져 있던 판단을 여기로 모은다 — 상태가 늘어나도 조건은 여기서만 바뀐다.

export interface EditorOpenInput {
  /** 피드에서 이 카드가 포커스를 받고 있는가 */
  isFocused: boolean
}

/** 카드를 펼쳐 에디터를 마운트할지 */
export function isEditorOpen({ isFocused }: EditorOpenInput): boolean {
  return isFocused
}
