// 노트 템플릿(BRU-44). 태그는 끝날 때, 템플릿은 시작할 때다.
//
// 빈 노트에서만 뜬다 — 이미 적은 글자가 있으면 `/`는 그냥 글자다.
// 그래야 본문에 손대지 않는다(원문 보존의 법칙).

import { matchesKey } from '../shortcuts/keys'

export interface NoteTemplate {
  id: string
  title: string
  /** 목록 오른쪽에 붙는 한 줄 설명 */
  hint: string
  content: string
}

export const NOTE_TEMPLATES: NoteTemplate[] = [
  {
    id: 'meeting',
    title: '회의 메모',
    hint: '논의·결정·다음 할 일',
    content: ['## 회의', '', '- 일시:', '- 참석:', '', '### 논의', '', '### 결정', '', '### 다음 할 일', ''].join(
      '\n'
    ),
  },
  {
    id: 'idea',
    title: '아이디어',
    hint: '무엇·왜·다음 단계',
    content: ['## 아이디어', '', '### 무엇', '', '### 왜', '', '### 다음 단계', ''].join('\n'),
  },
]

export interface ShouldOpenTemplateMenuInput {
  key: string
  content: string
  isLocked: boolean
}

/** 빈 노트에서 `/`를 쳤을 때만 템플릿 목록을 연다 */
export function shouldOpenTemplateMenu({
  key,
  content,
  isLocked,
}: ShouldOpenTemplateMenuInput): boolean {
  if (!matchesKey('insertTemplate', key)) return false
  if (isLocked) return false
  return content.trim().length === 0
}

/** 제목으로 좁힌다 (대소문자 무시) */
export function filterTemplates(query: string): NoteTemplate[] {
  const normalized = query.trim().toLowerCase()
  if (!normalized) return NOTE_TEMPLATES
  return NOTE_TEMPLATES.filter((template) => template.title.toLowerCase().includes(normalized))
}
