// Space 미리보기 패널의 규칙 (BRU-179).
//
// 패널은 **모달이 아니다.** macOS Finder의 Quick Look과 같은 자리다 — 열린 채로
// j/k가 뒤 목록을 계속 움직이고, 패널 내용이 그 포커스를 따라온다.
//
// 그래서 패널은 "지금 무엇을 보여줄지"를 스스로 기억하지 않는다. 열려 있는지
// 여부(boolean) 하나만 들고, 대상은 언제나 포커스된 노트다. 패널이 자기 노트 id를
// 따로 붙들면 j/k로 옮긴 순간 화면과 어긋난다 — 그 어긋남을 구조로 막는다.

export interface PreviewTargetInput {
  isPreviewOpen: boolean
  focusedNoteId: string | null
}

/** 지금 미리보기에 그릴 노트. 닫혀 있거나 포커스가 없으면 없다. */
export function previewTargetNoteId({
  isPreviewOpen,
  focusedNoteId,
}: PreviewTargetInput): string | null {
  if (!isPreviewOpen) return null
  return focusedNoteId
}

export interface TogglePreviewInput {
  focusedNoteId: string | null
  /** `v` 다중 선택 모드에 들어와 있는가 (BRU-80) */
  isSelecting: boolean
  /** 어느 카드든 편집 중인가 */
  isEditing: boolean
}

/**
 * Space를 미리보기로 받을 상황인가.
 *
 * 편집 중에는 Space가 글자이고, 선택 모드에서는 관용적으로 "선택 토글"의 자리다.
 * 둘 다 미리보기가 가져가면 안 되는 자리라 여기서 먼저 비켜선다.
 */
export function shouldTogglePreview({
  focusedNoteId,
  isSelecting,
  isEditing,
}: TogglePreviewInput): boolean {
  if (isEditing) return false
  if (isSelecting) return false
  return focusedNoteId !== null
}

export type EscapeAction = 'close-preview' | 'clear-focus'

/**
 * Escape 계층 (BRU-179).
 *
 * 패널이 열려 있으면 패널만 닫고 포커스는 남긴다. 한 번에 둘 다 풀리면
 * 훑던 자리를 잃어 다시 j를 여러 번 눌러야 한다.
 */
export function resolveEscapeAction({ isPreviewOpen }: { isPreviewOpen: boolean }): EscapeAction {
  return isPreviewOpen ? 'close-preview' : 'clear-focus'
}
