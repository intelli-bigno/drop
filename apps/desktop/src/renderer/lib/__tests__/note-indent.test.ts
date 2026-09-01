import { describe, expect, it } from 'vitest'
import { TREE_INDENT, noteIndentVars } from '../note-indent'

describe('noteIndentVars', () => {
  it('최상위 노트는 들여쓰기가 없다 — 변수 자체를 두지 않는다', () => {
    expect(noteIndentVars(0)).toBeUndefined()
  })

  it('깊이만큼 한 단씩 들여쓴다', () => {
    expect(noteIndentVars(1)).toEqual({ '--note-indent': `${TREE_INDENT}px` })
    expect(noteIndentVars(2)).toEqual({ '--note-indent': `${TREE_INDENT * 2}px` })
    expect(noteIndentVars(3)).toEqual({ '--note-indent': `${TREE_INDENT * 3}px` })
  })

  // buildNoteRows가 음수를 내는 경로는 없지만, 음수 패딩이 카드를 왼쪽으로
  // 끌어내면 레일과 본문이 어긋나는 것이 BRU-197에서 본 증상 그대로다
  it('음수 깊이는 들여쓰기 없음으로 본다', () => {
    expect(noteIndentVars(-1)).toBeUndefined()
  })
})
