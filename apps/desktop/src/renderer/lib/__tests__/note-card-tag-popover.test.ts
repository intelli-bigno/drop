import { describe, it, expect } from 'vitest'
import { readFileSync } from 'node:fs'
import { fileURLToPath } from 'node:url'

// 태그 팝오버가 "언제 열리는가"의 회귀 방지.
//
// BRU-44는 편집을 끝내는 순간 팝오버를 자동으로 여는 규칙을 넣었다("넘겨도 되는
// 제안"이라는 설계였다). 실사용에서는 한 줄 캡처마다 팝오버가 튀어나오는 마찰이었고,
// BRU-110에서 그 판단을 뒤집어 자동 오픈을 완전히 제거했다. 태그를 다는 길은
// `t`(명시적 진입) 하나다.
//
// 이 레포의 vitest는 node 환경 + `*.test.ts`만 돌린다 — 컴포넌트를 렌더해서
// 확인할 하네스가 없다. 그래서 소스 자체를 읽어 배선을 확인한다. 팝오버를 여는
// 배선은 손으로 세는 수준(두 군데)이라 이 정도 감시로 충분하다.
const source = readFileSync(
  fileURLToPath(new URL('../../components/NoteCard.tsx', import.meta.url)),
  'utf-8'
)

/** `const <name> = useCallback(` ... `}, [` 까지의 본문을 잘라낸다 */
function callbackBody(name: string): string {
  const start = source.indexOf(`const ${name} = useCallback(`)
  expect(start, `${name} 를 NoteCard.tsx 에서 찾지 못했다`).toBeGreaterThan(-1)
  const end = source.indexOf('\n      }, [', start)
  expect(end, `${name} 의 끝을 찾지 못했다`).toBeGreaterThan(start)
  return source.slice(start, end)
}

describe('NoteCard 태그 팝오버 배선', () => {
  it('shouldNotOpenTagPopoverWhenEditingEnds', () => {
    expect(callbackBody('handleEditorEscape')).not.toContain('setTagPopoverOpen(true)')
  })

  it('shouldNotConsultAnyEditEndAutoOpenRule', () => {
    expect(source).not.toContain('shouldOpenTagPopoverOnEditEnd')
  })

  // `t` → NoteFeed → 이 명령형 핸들. 자동 오픈을 지운 뒤에도 이 길은 남아야 한다.
  it('shouldStillOpenTagPopoverFromTheImperativeHandle', () => {
    const handle = source.slice(source.indexOf('openTagPopover: () => {'))
    expect(handle.slice(0, handle.indexOf('},'))).toContain('setTagPopoverOpen(true)')
  })
})
