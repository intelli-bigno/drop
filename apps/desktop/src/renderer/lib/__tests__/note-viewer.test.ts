import { describe, it, expect } from 'vitest'
import { parseNoteBlocks, parseInlineSpans } from '../note-viewer'

describe('parseNoteBlocks', () => {
  it('shouldReturnNothingForEmptyContent', () => {
    expect(parseNoteBlocks('')).toEqual([])
    expect(parseNoteBlocks('   \n  \n')).toEqual([])
  })

  it('shouldReadAPlainLineAsAParagraph', () => {
    expect(parseNoteBlocks('그냥 한 줄')).toEqual([{ type: 'paragraph', text: '그냥 한 줄' }])
  })

  it('shouldKeepASoftWrapInsideOneParagraph', () => {
    expect(parseNoteBlocks('첫 줄\n둘째 줄')).toEqual([
      { type: 'paragraph', text: '첫 줄\n둘째 줄' },
    ])
  })

  it('shouldSplitParagraphsOnABlankLine', () => {
    expect(parseNoteBlocks('앞\n\n뒤')).toEqual([
      { type: 'paragraph', text: '앞' },
      { type: 'paragraph', text: '뒤' },
    ])
  })

  it('shouldReadHeadingsWithTheirLevel', () => {
    expect(parseNoteBlocks('# 제목\n### 작은 제목')).toEqual([
      { type: 'heading', level: 1, text: '제목' },
      { type: 'heading', level: 3, text: '작은 제목' },
    ])
  })

  it('shouldCapTheHeadingLevelAtSix', () => {
    expect(parseNoteBlocks('####### 일곱개')).toEqual([
      { type: 'paragraph', text: '####### 일곱개' },
    ])
  })

  it('shouldGatherConsecutiveBulletsIntoOneList', () => {
    expect(parseNoteBlocks('- 하나\n- 둘\n* 셋')).toEqual([
      { type: 'list', ordered: false, items: ['하나', '둘', '셋'] },
    ])
  })

  it('shouldReadNumberedListsAsOrdered', () => {
    expect(parseNoteBlocks('1. 하나\n2. 둘')).toEqual([
      { type: 'list', ordered: true, items: ['하나', '둘'] },
    ])
  })

  it('shouldReadCheckboxesAsTaskItems', () => {
    expect(parseNoteBlocks('- [ ] 안 함\n- [x] 함')).toEqual([
      {
        type: 'tasks',
        items: [
          { checked: false, text: '안 함' },
          { checked: true, text: '함' },
        ],
      },
    ])
  })

  it('shouldReadAQuote', () => {
    expect(parseNoteBlocks('> 인용문\n> 이어짐')).toEqual([
      { type: 'quote', text: '인용문\n이어짐' },
    ])
  })

  it('shouldKeepACodeFenceVerbatim', () => {
    expect(parseNoteBlocks('```ts\nconst a = 1\n\nconst b = 2\n```')).toEqual([
      { type: 'code', language: 'ts', text: 'const a = 1\n\nconst b = 2' },
    ])
  })

  // 원문 보존 — 닫히지 않은 코드 펜스라도 내용을 잃지 않는다.
  it('shouldKeepAnUnclosedCodeFenceContent', () => {
    expect(parseNoteBlocks('```\n안 닫힘')).toEqual([
      { type: 'code', language: null, text: '안 닫힘' },
    ])
  })

  it('shouldReadAThematicBreak', () => {
    expect(parseNoteBlocks('앞\n\n---\n\n뒤')).toEqual([
      { type: 'paragraph', text: '앞' },
      { type: 'divider' },
      { type: 'paragraph', text: '뒤' },
    ])
  })
})

describe('parseInlineSpans', () => {
  it('shouldReadPlainTextAsOneSpan', () => {
    expect(parseInlineSpans('아무 표시 없음')).toEqual([
      { type: 'text', text: '아무 표시 없음' },
    ])
  })

  it('shouldReadBoldRuns', () => {
    expect(parseInlineSpans('앞 **굵게** 뒤')).toEqual([
      { type: 'text', text: '앞 ' },
      { type: 'strong', text: '굵게' },
      { type: 'text', text: ' 뒤' },
    ])
  })

  it('shouldReadInlineCode', () => {
    expect(parseInlineSpans('값은 `x = 1` 이다')).toEqual([
      { type: 'text', text: '값은 ' },
      { type: 'code', text: 'x = 1' },
      { type: 'text', text: ' 이다' },
    ])
  })

  it('shouldReadMarkdownLinks', () => {
    expect(parseInlineSpans('[DROP](https://example.com) 참고')).toEqual([
      { type: 'link', text: 'DROP', href: 'https://example.com' },
      { type: 'text', text: ' 참고' },
    ])
  })

  it('shouldReadBareUrlsAsLinks', () => {
    expect(parseInlineSpans('보기 https://example.com/a 끝')).toEqual([
      { type: 'text', text: '보기 ' },
      { type: 'link', text: 'https://example.com/a', href: 'https://example.com/a' },
      { type: 'text', text: ' 끝' },
    ])
  })

  it('shouldNotTreatCodeContentAsAnythingElse', () => {
    expect(parseInlineSpans('`**굵지 않다**`')).toEqual([
      { type: 'code', text: '**굵지 않다**' },
    ])
  })

  // 원문 보존 — 짝이 맞지 않는 마커는 글자 그대로 남는다. 지우지 않는다.
  it('shouldLeaveUnmatchedMarkersAsLiteralText', () => {
    expect(parseInlineSpans('**안 닫힘')).toEqual([{ type: 'text', text: '**안 닫힘' }])
    expect(parseInlineSpans('snake_case_이름')).toEqual([
      { type: 'text', text: 'snake_case_이름' },
    ])
  })

  // 어떤 입력이든 span의 글자를 이으면 원문이 나와야 한다 (링크 제외 — href는 별도).
  it('shouldNeverDropCharactersFromPlainText', () => {
    const raw = '별 * 하나 _언더바_ 백틱 ` 하나'
    const joined = parseInlineSpans(raw)
      .map((span) => (span.type === 'code' ? `\`${span.text}\`` : span.text))
      .join('')
    expect(joined).toBe(raw)
  })
})
