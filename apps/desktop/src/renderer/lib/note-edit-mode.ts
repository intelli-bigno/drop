// 노트 카드가 펼쳐져 있는지(= Lexical 에디터가 마운트되는지)를 정하는 한 곳.
//
// BRU-53 — 포커스와 펼침은 다른 것이다. j/k/클릭으로 포커스가 옮겨가도 카드는
// 한 줄 그대로여야 하고, `/`·`i`로 편집에 들어갔을 때만 펼쳐진다.

export interface EditorOpenInput {
  /** 피드에서 이 카드가 포커스를 받고 있는가 */
  isFocused: boolean
  /** `/`·`i`로 편집에 들어와 있는가 */
  isEditing: boolean
}

/** 카드를 펼쳐 에디터를 마운트할지 */
export function isEditorOpen({ isFocused, isEditing }: EditorOpenInput): boolean {
  return isFocused && isEditing
}
