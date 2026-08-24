/**
 * 노트 참조 문자열 (BRU-104).
 *
 * Linear가 이슈를 `[BRU-61: 제목](url)`로 복사해 주는 것과 같은 모양으로 Drop 노트를 복사한다.
 * `drop://note/<uuid>`가 두 가지 일을 한다 — 붙여넣은 텍스트가 "Drop 노트"임을 알리는 표시이자,
 * 에이전트가 `mcp__drop__get_note`에 그대로 넘길 UUID의 운반 수단이다.
 * (MCP는 이미 UUID를 받으므로 서버 쪽에 더 붙일 것이 없다.)
 *
 * 순수 모듈이다 — Electron도 DOM도 부르지 않아 vitest로 그대로 덮인다.
 */

export const DROP_NOTE_URI_PREFIX = 'drop://note/'

/** 제목 기본 상한. Linear 제목과 비슷한 길이감에 맞췄다. */
export const DEFAULT_TITLE_MAX_LENGTH = 80

/** 본문이 비어 있는 노트의 자리표시자 — 링크 제목이 빈 채로 나가면 무엇인지 알 수 없다. */
export const EMPTY_TITLE_PLACEHOLDER = '(빈 노트)'

export interface NoteReferenceInput {
  id: string
  displayId: number
  content: string
}

export function noteUri(noteId: string): string {
  return `${DROP_NOTE_URI_PREFIX}${noteId}`
}

/**
 * 본문에서 링크 제목을 뽑는다.
 *
 * 첫 줄만 쓴다 — 마크다운 링크는 한 줄이라 줄바꿈이 섞이면 구조가 깨진다.
 * 대괄호는 링크 문법 자체를 깨므로 이스케이프한다.
 */
export function noteReferenceTitle(
  content: string,
  options: { maxLength?: number } = {}
): string {
  const maxLength = options.maxLength ?? DEFAULT_TITLE_MAX_LENGTH

  const firstLine = content
    .split('\n')
    .map((line) => line.trim())
    .find((line) => line.length > 0)

  if (!firstLine) return EMPTY_TITLE_PLACEHOLDER

  const collapsed = firstLine.replace(/\s+/g, ' ')
  const truncated =
    collapsed.length > maxLength ? `${collapsed.slice(0, maxLength - 1)}…` : collapsed

  return truncated.replace(/([[\]])/g, '\\$1')
}

/** `[DROP #211: 제목](drop://note/<uuid>)` — 붙여넣으면 한 줄로 끝난다. */
export function buildNoteReference(
  note: NoteReferenceInput,
  options: { maxLength?: number } = {}
): string {
  const title = noteReferenceTitle(note.content, options)
  return `[DROP #${note.displayId}: ${title}](${noteUri(note.id)})`
}
