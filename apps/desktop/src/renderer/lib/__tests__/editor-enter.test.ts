import { describe, it, expect } from 'vitest'
import { decideEditorEnter } from '../editor-enter'

// 인라인 Lexical 에디터의 Enter 계약 (BRU-134 · BRU-130).
//
// Lexical 커맨드 핸들러는 jsdom 없이 돌리기 어렵다. 판단만 순수 함수로 떼어
// 여기서 못 박고, 배선은 별도 소스 스캔 테스트가 본다.
//
// 반환값:
//   ignore     — IME 조합 중. 기본 동작을 건드리지 않는다
//   insertLine — 코드 블록 안에서 줄만 넣는다 (노드를 쪼개지 않는다)
//   pass       — Lexical 기본(단락 삽입). onEscape를 부르지 않는다
//
// 'escape'(저장+종료)는 어떤 입력에도 나오지 않는다. 종료는 Esc의 일이다.

describe('decideEditorEnter', () => {
  it('shouldIgnoreEnterWhileImeIsComposing', () => {
    expect(decideEditorEnter({ isComposing: true, inCodeBlock: false })).toBe('ignore')
    expect(decideEditorEnter({ isComposing: true, inCodeBlock: true })).toBe('ignore')
  })

  // BRU-134 — 본문에서 Enter는 줄을 넣고 카드를 닫지 않는다
  it('shouldPassPlainEnterOutsideACodeBlockSoLexicalInsertsALine', () => {
    expect(decideEditorEnter({ isComposing: false, inCodeBlock: false })).toBe('pass')
  })

  // BRU-130 — 코드 블록 안 Enter는 블록을 쪼개지 않고 줄만 넣는다
  it('shouldInsertALineInsideACodeBlock', () => {
    expect(decideEditorEnter({ isComposing: false, inCodeBlock: true })).toBe('insertLine')
  })

  it('shouldNeverTreatEnterAsSaveAndExit', () => {
    const cases = [
      { isComposing: false, inCodeBlock: false },
      { isComposing: false, inCodeBlock: true },
      { isComposing: true, inCodeBlock: false },
      { isComposing: true, inCodeBlock: true },
    ]
    for (const input of cases) {
      expect(decideEditorEnter(input)).not.toBe('escape')
    }
  })
})
