import { describe, it, expect } from 'vitest'
import { unescapeSerializedMarkdown, reconcileSerializedMarkdown } from '../markdown-fidelity'

// BRU-66 — @lexical/markdown이 plain text 노드에 먹이는 이스케이프를 되돌린다.
// LexicalMarkdown.dev.js: output.replace(/([*_`~\\])/g, '\\$1')
describe('unescapeSerializedMarkdown', () => {
  it('shouldRestoreUnderscoresInsideUrl', () => {
    expect(
      unescapeSerializedMarkdown('https://example.com/a?utm\\_source=x&utm\\_medium=y')
    ).toBe('https://example.com/a?utm_source=x&utm_medium=y')
  })

  it('shouldRestoreTildeInKoreanRange', () => {
    expect(unescapeSerializedMarkdown('2\\~3시간')).toBe('2~3시간')
  })

  it('shouldRestoreAsteriskAndBacktick', () => {
    expect(unescapeSerializedMarkdown('a \\* b \\` c')).toBe('a * b ` c')
  })

  // 원문에 이미 백슬래시 이스케이프가 있던 경우 — 왕복 후에도 원문 그대로여야 한다.
  // 원문 `\_`(2자)는 직렬화되며 `\\` + `\_`(4자)가 된다.
  it('shouldRoundTripLiteralBackslashEscape', () => {
    const original = String.raw`\_`
    const serialized = String.raw`\\\_`
    expect(unescapeSerializedMarkdown(serialized)).toBe(original)
  })

  it('shouldLeaveUnrelatedBackslashesAlone', () => {
    expect(unescapeSerializedMarkdown('C:\\path\\to')).toBe('C:\\path\\to')
  })

  it('shouldLeaveRealFormattingMarkersAlone', () => {
    // 포맷 노드가 만든 `**` · `_`는 이스케이프되지 않은 채로 온다 — 건드리면 안 된다
    expect(unescapeSerializedMarkdown('**굵게** 그리고 _기울임_')).toBe(
      '**굵게** 그리고 _기울임_'
    )
  })
})

describe('reconcileSerializedMarkdown', () => {
  // (a) URL·물결 — 이스케이프만 다른 경우 원문을 그대로 돌려준다
  it('shouldKeepOriginalWhenOnlyEscapesDiffer', () => {
    const original = '링크 정리\nhttps://example.com/a?utm_source=x&utm_medium=y\n소요 2~3시간'
    const serialized = '링크 정리\nhttps://example.com/a?utm\\_source=x&utm\\_medium=y\n소요 2\\~3시간'
    expect(reconcileSerializedMarkdown(original, serialized)).toBe(original)
  })

  // (b) 줄 끝 공백이 깎여 돌아온 경우 — 원문의 공백을 지킨다
  it('shouldKeepOriginalTrailingSpaces', () => {
    const original = '첫 줄 끝에 공백 두 개  \n둘째 줄  \n셋째 줄'
    const serialized = '첫 줄 끝에 공백 두 개\n둘째 줄\n셋째 줄'
    expect(reconcileSerializedMarkdown(original, serialized)).toBe(original)
  })

  // (c) 리스트 앞에 빈 줄이 끼어든 경우 — 원문을 지킨다
  it('shouldKeepOriginalWhenBlankLineInsertedBeforeList', () => {
    const original = '할 일\n- 항목 하나\n- 항목 둘\n\n끝'
    const serialized = '할 일\n\n- 항목 하나\n- 항목 둘\n\n끝'
    expect(reconcileSerializedMarkdown(original, serialized)).toBe(original)
  })

  it('shouldKeepOriginalWhenBlankLineInsertedAfterList', () => {
    const original = '- 항목 하나\n끝'
    const serialized = '- 항목 하나\n\n끝'
    expect(reconcileSerializedMarkdown(original, serialized)).toBe(original)
  })

  it('shouldKeepOriginalForOrderedList', () => {
    const original = '할 일\n1. 하나\n2. 둘'
    const serialized = '할 일\n\n1. 하나\n2. 둘'
    expect(reconcileSerializedMarkdown(original, serialized)).toBe(original)
  })

  it('shouldKeepOriginalWhenIdentical', () => {
    const original = '그냥 한 줄'
    expect(reconcileSerializedMarkdown(original, original)).toBe(original)
  })

  // 실제로 글자가 바뀌었으면 새 본문을 쓴다 — 단, 이스케이프는 벗겨서
  it('shouldPersistRealEditWithoutEscapes', () => {
    const original = '링크 정리\nhttps://example.com/a?utm_source=x'
    const serialized = '링크 정리!\nhttps://example.com/a?utm\\_source=x'
    expect(reconcileSerializedMarkdown(original, serialized)).toBe(
      '링크 정리!\nhttps://example.com/a?utm_source=x'
    )
  })

  it('shouldPreserveDeliberateMarkdownFormatting', () => {
    const original = '메모'
    const serialized = '메모 **굵게** _기울임_'
    expect(reconcileSerializedMarkdown(original, serialized)).toBe('메모 **굵게** _기울임_')
  })

  it('shouldPersistEmptyContent', () => {
    expect(reconcileSerializedMarkdown('원문', '')).toBe('')
  })

  // 실제 편집이 일어나도 손대지 않은 줄의 원문 바이트는 지킨다
  it('shouldKeepTrailingSpacesOnUntouchedLinesDuringRealEdit', () => {
    const original = '첫 줄 끝에 공백 두 개  \n둘째 줄  \n셋째 줄'
    const serialized = '첫 줄 끝에 공백 두 개\n둘째 줄\n셋째 줄X'
    expect(reconcileSerializedMarkdown(original, serialized)).toBe(
      '첫 줄 끝에 공백 두 개  \n둘째 줄  \n셋째 줄X'
    )
  })

  it('shouldNotInsertBlankLineBeforeListDuringRealEdit', () => {
    const original = '할 일\n- 항목 하나\n- 항목 둘\n\n끝'
    const serialized = '할 일!\n\n- 항목 하나\n- 항목 둘\n\n끝'
    expect(reconcileSerializedMarkdown(original, serialized)).toBe(
      '할 일!\n- 항목 하나\n- 항목 둘\n\n끝'
    )
  })

  it('shouldKeepUrlIntactWhenAnotherLineChanges', () => {
    const original = '링크 정리\nhttps://example.com/a?utm_source=x&utm_medium=y\n소요 2~3시간'
    const serialized =
      '링크 정리!\nhttps://example.com/a?utm\\_source=x&utm\\_medium=y\n소요 2\\~3시간'
    expect(reconcileSerializedMarkdown(original, serialized)).toBe(
      '링크 정리!\nhttps://example.com/a?utm_source=x&utm_medium=y\n소요 2~3시간'
    )
  })

  it('shouldAppendNewLines', () => {
    const original = '한 줄  '
    const serialized = '한 줄\n새 줄'
    expect(reconcileSerializedMarkdown(original, serialized)).toBe('한 줄  \n새 줄')
  })

  it('shouldDropRemovedLines', () => {
    const original = '하나  \n둘  \n셋  '
    const serialized = '하나\n셋'
    expect(reconcileSerializedMarkdown(original, serialized)).toBe('하나  \n셋  ')
  })
})
