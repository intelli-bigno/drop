// 인라인 Lexical 에디터에서 Enter가 무엇을 하는지.
//
// BRU-134: 본문에서 Enter는 줄을 넣고 편집을 끝내지 않는다. 종료는 Esc.
// BRU-130: 코드 블록 안에서는 Enter/Shift+Enter가 블록을 쪼개지 않고 줄만 넣는다.
// 퀵캡처의 Enter=제출은 여기 없다.

export type EditorEnterAction = 'ignore' | 'insertLine' | 'pass'

export function decideEditorEnter(input: {
  isComposing: boolean
  inCodeBlock: boolean
}): EditorEnterAction {
  if (input.isComposing) return 'ignore'
  if (input.inCodeBlock) return 'insertLine'
  return 'pass'
}
