// 삭제 확인 다이얼로그 문구.
// 연속 정리 중에도 "지금 지우는 게 무엇인지"가 보여야 오조작을 그 자리에서 알아챈다.

const PREVIEW_MAX_LENGTH = 60

interface DeletableNote {
  content: string
  attachmentCount: number
}

export function buildDeleteConfirmMessage({ content, attachmentCount }: DeletableNote): string {
  const collapsed = content.replace(/\s+/g, ' ').trim()
  const preview =
    collapsed === ''
      ? '(빈 노트)'
      : collapsed.length <= PREVIEW_MAX_LENGTH
        ? `"${collapsed}"`
        : `"${collapsed.slice(0, PREVIEW_MAX_LENGTH)}…"`

  const attachments = attachmentCount > 0 ? ` · 첨부 ${attachmentCount}개` : ''

  return `${preview}${attachments}\n\n휴지통으로 이동합니다.`
}
