// 일반 URL 감지 정규식 (http/https)
//
// BRU-67: /g 플래그가 붙은 정규식 객체는 .test() 호출마다 lastIndex를 남긴다.
// 하나의 모듈 상수를 여러 노트에 재사용하면 URL이 있는 노트가 하나 걸러 하나씩
// false로 나온다. 그래서 감지용(비전역)과 추출용(전역)을 분리한다.
const URL_PATTERN = 'https?://[^\\s<>"{}|\\\\^`[\\]]+'
const URL_REGEX = new RegExp(URL_PATTERN, 'i')
const URL_REGEX_GLOBAL = new RegExp(URL_PATTERN, 'gi')

/**
 * 텍스트에서 URL 존재 여부 감지
 */
export function hasUrlInText(text: string): boolean {
  if (!text) return false
  return URL_REGEX.test(text)
}

/**
 * 텍스트에서 모든 URL 추출
 */
export function extractUrls(text: string): string[] {
  if (!text) return []
  // String.match(/g)는 정규식 객체의 lastIndex를 건드리지 않지만,
  // 감지용과 같은 객체를 공유하지 않도록 전역 전용 인스턴스를 쓴다.
  const matches = text.match(URL_REGEX_GLOBAL)
  return matches ? Array.from(new Set(matches)) : []
}
