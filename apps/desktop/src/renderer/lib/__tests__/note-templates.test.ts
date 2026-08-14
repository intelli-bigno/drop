import { describe, it, expect } from 'vitest'
import {
  NOTE_TEMPLATES,
  filterTemplates,
  shouldOpenTemplateMenu,
} from '../note-templates'

describe('NOTE_TEMPLATES', () => {
  it('바로 넣을 수 있는 기본 템플릿을 들고 있다', () => {
    expect(NOTE_TEMPLATES.length).toBeGreaterThanOrEqual(2)
    for (const template of NOTE_TEMPLATES) {
      expect(template.content.trim().length).toBeGreaterThan(0)
    }
  })

  it('id가 겹치지 않는다', () => {
    const ids = NOTE_TEMPLATES.map((t) => t.id)
    expect(new Set(ids).size).toBe(ids.length)
  })
})

describe('shouldOpenTemplateMenu', () => {
  it('빈 노트에서 /를 치면 연다', () => {
    expect(shouldOpenTemplateMenu({ key: '/', content: '', isLocked: false })).toBe(true)
  })

  it('공백뿐인 노트도 빈 노트로 본다', () => {
    expect(shouldOpenTemplateMenu({ key: '/', content: '  \n ', isLocked: false })).toBe(true)
  })

  it('내용이 있으면 열지 않는다 — 본문의 /는 그냥 글자다', () => {
    expect(shouldOpenTemplateMenu({ key: '/', content: 'a/b', isLocked: false })).toBe(false)
  })

  it('다른 키에는 반응하지 않는다', () => {
    expect(shouldOpenTemplateMenu({ key: 't', content: '', isLocked: false })).toBe(false)
  })

  it('잠긴 노트에서는 열지 않는다', () => {
    expect(shouldOpenTemplateMenu({ key: '/', content: '', isLocked: true })).toBe(false)
  })
})

describe('filterTemplates', () => {
  it('입력이 없으면 전부 준다', () => {
    expect(filterTemplates('')).toHaveLength(NOTE_TEMPLATES.length)
  })

  it('제목 일부로 좁힌다', () => {
    const meeting = NOTE_TEMPLATES.find((t) => t.id === 'meeting')!
    expect(filterTemplates('회의').map((t) => t.id)).toContain(meeting.id)
    expect(filterTemplates('회의').every((t) => t.title.includes('회의'))).toBe(true)
  })

  it('맞는 게 없으면 빈 목록을 준다', () => {
    expect(filterTemplates('zzzz그런거없음')).toEqual([])
  })
})
