/**
 * ⌘C 가로채기 판정 (BRU-104).
 *
 * ⌘C를 "포커스된 노트 복사"에 묶되, 사용자가 텍스트를 긁어 놓은 상태에서는
 * OS 복사를 그대로 둔다 — 선택 영역 복사를 빼앗는 것은 회귀다.
 * (편집 중인지 여부는 기존 `isTextInputTarget` 가드가 앞에서 걸러 준다.)
 */
export function shouldYieldToNativeCopy(state: { selectionText: string | null }): boolean {
  return (state.selectionText ?? '').trim().length > 0
}
