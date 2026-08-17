// 노트 본문은 평문 마크다운으로 저장된다. 에디터는 그것을 Lexical 트리로 파싱했다가
// 다시 마크다운으로 직렬화하는데, 이 왕복이 원문을 바꿔 놓는다 (BRU-66).
//
//  (a) `@lexical/markdown`이 plain text 노드의 `* _ ` ~ \` 앞에 백슬래시를 붙인다
//      → URL의 `_`가 `\_`가 되어 링크가 깨진다
//  (b) 줄 끝 공백이 사라진다
//  (c) 리스트 블록 앞뒤에 빈 줄이 끼어든다
//
// (a)는 직렬화의 역함수가 존재하므로 되돌린다. (b)·(c)는 되돌릴 수 없으므로,
// "직렬화 결과가 원문과 실질적으로 같다면 원문 바이트를 그대로 유지한다"로 막는다.

const ESCAPED_MARKDOWN_CHAR = /\\([\\*_`~])/g

const LIST_ITEM = /^\s*(?:[-*+]|\d+[.)])\s/

/** 직렬화가 덧붙인 마크다운 이스케이프를 되돌린다. */
export function unescapeSerializedMarkdown(markdown: string): string {
  return markdown.replace(ESCAPED_MARKDOWN_CHAR, '$1')
}

function isListItem(line: string | undefined): boolean {
  return line !== undefined && LIST_ITEM.test(line)
}

// 왕복이 만들어내는 잡음(줄 끝 공백·리스트 주변 빈 줄)을 걷어낸 비교용 형태.
// 실제 저장값을 만드는 데는 쓰지 않는다 — 오직 "달라졌는가" 판정에만 쓴다.
function normalizeForComparison(markdown: string): string {
  const lines = markdown.split('\n').map((line) => line.replace(/[ \t]+$/, ''))
  const kept: string[] = []
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i]
    if (line === '' && (isListItem(lines[i + 1]) || isListItem(lines[i - 1]))) continue
    kept.push(line)
  }
  return kept.join('\n')
}

// 줄 단위 LCS. 아주 긴 본문에서는 계산을 포기하고 직렬화 결과를 그대로 쓴다.
const MAX_DIFF_CELLS = 250_000

function lcsTable(a: string[], b: string[]): number[][] {
  const dp: number[][] = Array.from({ length: a.length + 1 }, () => new Array(b.length + 1).fill(0))
  for (let i = a.length - 1; i >= 0; i--) {
    for (let j = b.length - 1; j >= 0; j--) {
      dp[i][j] = a[i] === b[j] ? dp[i + 1][j + 1] + 1 : Math.max(dp[i + 1][j], dp[i][j + 1])
    }
  }
  return dp
}

// 바뀌지 않은 줄은 원문 바이트를 그대로 쓰고, 바뀐 줄만 새 줄로 채운다.
// 왕복이 만들어낸 빈 줄(리스트 앞뒤)은 새 줄로 치지 않는다.
function mergeLineByLine(originalLines: string[], nextLines: string[]): string[] {
  const a = originalLines.map((line) => line.replace(/[ \t]+$/, ''))
  const b = nextLines.map((line) => line.replace(/[ \t]+$/, ''))
  const dp = lcsTable(a, b)

  const merged: string[] = []
  let i = 0
  let j = 0
  while (i < a.length || j < b.length) {
    if (i < a.length && j < b.length && a[i] === b[j]) {
      // 같은 줄 — 원문 그대로 (줄 끝 공백 보존)
      merged.push(originalLines[i])
      i++
      j++
    } else if (j < b.length && (i >= a.length || dp[i][j + 1] >= dp[i + 1][j])) {
      const isNoiseBlankLine =
        nextLines[j] === '' && (isListItem(b[j + 1]) || isListItem(b[j - 1]))
      if (!isNoiseBlankLine) merged.push(nextLines[j])
      j++
    } else {
      i++
    }
  }
  return merged
}

/**
 * 에디터가 내놓은 직렬화 결과를 실제로 저장할 본문으로 바꾼다.
 * 원문과 실질적으로 같으면 원문을 그대로 돌려주고, 달라졌으면 바뀐 줄만 갈아 끼운다.
 * 원문 보존이 우선이다 (BRU-66).
 */
export function reconcileSerializedMarkdown(original: string, serialized: string): string {
  const unescaped = unescapeSerializedMarkdown(serialized)
  if (normalizeForComparison(unescaped) === normalizeForComparison(original)) return original
  if (unescaped === '' || original === '') return unescaped

  const originalLines = original.split('\n')
  const nextLines = unescaped.split('\n')
  if (originalLines.length * nextLines.length > MAX_DIFF_CELLS) return unescaped

  return mergeLineByLine(originalLines, nextLines).join('\n')
}
