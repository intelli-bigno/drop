// 한 줄 카드(BRU-46)에서 노트를 한 줄로 요약하는 규칙.
//
// 노트 하나 = 한 줄이다. 본문은 줄바꿈이 있어도 공백으로 이어 붙여 한 줄로 만들고,
// 넘치는 부분은 CSS(text-overflow: ellipsis)가 자른다 — 문자 수로 자르지 않는다.
//
// 마크다운 표시는 **블록도 인라인도** 떼어낸다 (BRU-213). 블록 마커(#, -, 1., >)만
// 떼던 때는 목록에서 `**형광펜**`이 별표째 보였다 — 펼치면 굵은 글씨인데 접으면
// 별표인 셈이라, 같은 노트가 두 가지 글로 보였다.
//
// 인라인은 뷰어와 **같은 파서**(parseInlineSpans)로 떼어낸다. 정규식을 따로 두면
// 언젠가 둘이 갈라져서, 목록에서 지워지는 표시와 뷰어가 그리는 표시가 어긋난다.

import { extractUrls } from './url-utils'
import { parseInlineSpans } from './note-viewer'

/** 줄 앞의 마크다운 블록 마커 — 제목·불릿·번호·인용 */
const LINE_MARKER = /^\s*(?:#{1,6}\s+|[-*+]\s+|\d+\.\s+|>\s*)/

/** 코드 펜스 줄 — 글자가 하나도 없으므로 한 줄 요약에서는 없는 편이 낫다 */
const CODE_FENCE = /^\s*```/

/** 인라인 표시를 떼고 보이는 글자만 남긴다 */
function stripInline(line: string): string {
  return parseInlineSpans(line)
    .map((span) => span.text)
    .join('')
}

/** 노트 본문을 한 줄 미리보기 문자열로 만든다 */
export function toSingleLinePreview(content: string): string {
  if (!content) return ''

  return content
    .split('\n')
    .filter((line) => !CODE_FENCE.test(line))
    .map((line) => stripInline(line.replace(LINE_MARKER, '')))
    .join(' ')
    .replace(/\s+/g, ' ')
    .trim()
}

/** 본문에 들어 있는 링크 개수 — 같은 URL이 여러 번 나와도 하나로 센다 */
export function countContentLinks(content: string): number {
  return extractUrls(content).length
}
