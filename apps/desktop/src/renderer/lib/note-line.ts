// 한 줄 카드(BRU-46)에서 노트를 한 줄로 요약하는 규칙.
//
// 노트 하나 = 한 줄이다. 본문은 줄바꿈이 있어도 공백으로 이어 붙여 한 줄로 만들고,
// 넘치는 부분은 CSS(text-overflow: ellipsis)가 자른다 — 문자 수로 자르지 않는다.
// 마크다운 블록 마커(#, -, 1., >)는 한 줄에서는 소음이라 떼어낸다.

import { extractUrls } from './url-utils'

/** 줄 앞의 마크다운 블록 마커 — 제목·불릿·번호·인용 */
const LINE_MARKER = /^\s*(?:#{1,6}\s+|[-*+]\s+|\d+\.\s+|>\s*)/

/** 노트 본문을 한 줄 미리보기 문자열로 만든다 */
export function toSingleLinePreview(content: string): string {
  if (!content) return ''

  return content
    .split('\n')
    .map((line) => line.replace(LINE_MARKER, ''))
    .join(' ')
    .replace(/\s+/g, ' ')
    .trim()
}

/** 본문에 들어 있는 링크 개수 — 같은 URL이 여러 번 나와도 하나로 센다 */
export function countContentLinks(content: string): number {
  return extractUrls(content).length
}
