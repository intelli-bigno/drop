import { describe, expect, it } from 'vitest'
import {
  DROP_NOTE_URI_PREFIX,
  buildNoteReference,
  noteReferenceTitle,
  noteUri,
} from './note-reference'

const NOTE = {
  id: 'a50ce86b-6f94-4662-b197-799a4afd646d',
  displayId: 211,
  content: 'drop > os단 quick add 단축키 변경',
}

describe('noteUri', () => {
  it('UUID를 담은 drop:// URI를 만든다 — 에이전트가 Drop 노트임을 알아보는 표시다', () => {
    expect(noteUri(NOTE.id)).toBe(`${DROP_NOTE_URI_PREFIX}a50ce86b-6f94-4662-b197-799a4afd646d`)
  })
})

describe('noteReferenceTitle', () => {
  it('본문 첫 줄을 제목으로 쓴다', () => {
    expect(noteReferenceTitle('첫 줄\n둘째 줄\n셋째 줄')).toBe('첫 줄')
  })

  it('앞뒤 공백과 줄 안의 연속 공백을 정리한다', () => {
    expect(noteReferenceTitle('  여러   칸   띄운   제목  \n본문')).toBe('여러 칸 띄운 제목')
  })

  it('앞의 빈 줄은 건너뛰고 내용이 있는 첫 줄을 찾는다', () => {
    expect(noteReferenceTitle('\n\n  \n실제 첫 줄\n다음')).toBe('실제 첫 줄')
  })

  it('마크다운 링크를 깨는 대괄호는 이스케이프한다', () => {
    expect(noteReferenceTitle('[중요] 처리 [완료]')).toBe('\\[중요\\] 처리 \\[완료\\]')
  })

  it('너무 길면 말줄임한다', () => {
    const long = 'ㄱ'.repeat(200)
    const title = noteReferenceTitle(long)
    expect(title.length).toBeLessThanOrEqual(80)
    expect(title.endsWith('…')).toBe(true)
  })

  it('말줄임 길이를 조정할 수 있다', () => {
    expect(noteReferenceTitle('abcdefghij', { maxLength: 5 })).toBe('abcd…')
  })

  it('본문이 비어 있으면 빈 노트임을 알리는 자리표시자를 쓴다', () => {
    expect(noteReferenceTitle('')).toBe('(빈 노트)')
    expect(noteReferenceTitle('   \n  ')).toBe('(빈 노트)')
  })
})

describe('buildNoteReference', () => {
  it('Linear와 같은 한 줄 마크다운 링크를 만든다', () => {
    expect(buildNoteReference(NOTE)).toBe(
      '[DROP #211: drop > os단 quick add 단축키 변경](drop://note/a50ce86b-6f94-4662-b197-799a4afd646d)'
    )
  })

  it('여러 줄 노트는 첫 줄만 제목으로 쓴다 — 링크가 줄바꿈으로 깨지지 않는다', () => {
    const reference = buildNoteReference({ ...NOTE, content: '제목 줄\n본문 줄\n또 본문' })
    expect(reference).toBe(
      '[DROP #211: 제목 줄](drop://note/a50ce86b-6f94-4662-b197-799a4afd646d)'
    )
    expect(reference.includes('\n')).toBe(false)
  })

  it('제목에 괄호가 있어도 링크 구조가 유지된다', () => {
    const reference = buildNoteReference({ ...NOTE, content: '[TODO] 확인' })
    expect(reference).toBe(
      '[DROP #211: \\[TODO\\] 확인](drop://note/a50ce86b-6f94-4662-b197-799a4afd646d)'
    )
  })
})
