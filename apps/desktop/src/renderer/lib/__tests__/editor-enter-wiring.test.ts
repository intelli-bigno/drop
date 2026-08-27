import { describe, it, expect } from 'vitest'
import { readFileSync } from 'node:fs'
import { fileURLToPath } from 'node:url'

// 인라인 에디터 Enter·스크롤 배선 회귀 (BRU-134 · BRU-130).
//
// vitest는 컴포넌트를 렌더하지 않으므로 소스 자체를 읽는다.
// 판단 로직은 editor-enter.test.ts 가 보고, 여기는 "그 판단이 실제로
// 플러그인에 붙어 있는가"와 "퀵캡처 Enter=제출을 건드리지 않았는가"다.

const editorSource = readFileSync(
  fileURLToPath(new URL('../../components/LexicalEditor.tsx', import.meta.url)),
  'utf-8'
)
const quickCaptureSource = readFileSync(
  fileURLToPath(new URL('../../components/QuickCapture.tsx', import.meta.url)),
  'utf-8'
)
const cssSource = readFileSync(
  fileURLToPath(new URL('../../styles/index.css', import.meta.url)),
  'utf-8'
)

function cssRule(className: string): string {
  const start = cssSource.indexOf(`.${className} {`)
  expect(start, `.${className} 규칙을 찾지 못했다`).toBeGreaterThan(-1)
  const end = cssSource.indexOf('\n}', start)
  expect(end, `.${className} 규칙의 끝을 찾지 못했다`).toBeGreaterThan(start)
  return cssSource.slice(start, end)
}

function commandHandler(source: string, command: string): string {
  const start = source.indexOf(`editor.registerCommand(\n      ${command}`)
  expect(start, `${command} 등록을 찾지 못했다`).toBeGreaterThan(-1)
  const end = source.indexOf('COMMAND_PRIORITY_', start)
  expect(end, `${command} 핸들러의 끝을 찾지 못했다`).toBeGreaterThan(start)
  return source.slice(start, end)
}

describe('LexicalEditor Enter 배선 (BRU-134 · BRU-130)', () => {
  it('shouldDecideEnterWithThePureHelper', () => {
    expect(editorSource).toContain('decideEditorEnter')
  })

  it('shouldNotCallOnEscapeFromTheEnterCommand', () => {
    const enter = commandHandler(editorSource, 'KEY_ENTER_COMMAND')
    expect(enter).not.toContain('onEscape()')
  })

  it('shouldInsertALineBreakInsideACodeBlockInsteadOfSplittingIt', () => {
    const enter = commandHandler(editorSource, 'KEY_ENTER_COMMAND')
    expect(enter).toContain('insertLineBreak')
    expect(enter).not.toContain('insertParagraph')
  })

  it('shouldStillSaveAndExitOnEscape', () => {
    expect(editorSource).toContain("if (e.key !== 'Escape') return")
    const escapeHandlerStart = editorSource.indexOf("if (e.key !== 'Escape') return")
    const escapeHandler = editorSource.slice(escapeHandlerStart, escapeHandlerStart + 250)
    expect(escapeHandler).toContain('onEscape()')
  })
})

describe('QuickCapture Enter 배선 (BRU-134 범위 밖)', () => {
  it('shouldStillSubmitOnPlainEnter', () => {
    expect(quickCaptureSource).toContain("e.key === 'Enter' && !e.shiftKey")
    const start = quickCaptureSource.indexOf("e.key === 'Enter' && !e.shiftKey")
    const snippet = quickCaptureSource.slice(start, start + 120)
    expect(snippet).toContain('handleSubmit()')
  })
})

describe('편집 중 에디터 본문 스크롤 (BRU-130)', () => {
  it('shouldConstrainTheEditorBodyWithMaxHeightAndScroll', () => {
    const rule = cssRule('note-editor')
    expect(rule).toContain('max-height')
    expect(rule).toMatch(/overflow-y:\s*auto/)
  })

  it('shouldScrollTheCaretIntoViewOnEditorUpdates', () => {
    expect(editorSource).toContain('applyCaretScroll')
  })
})
