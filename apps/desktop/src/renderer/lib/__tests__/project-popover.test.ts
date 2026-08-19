import { describe, it, expect } from 'vitest'
import type { Project } from '@drop/shared'
import {
  normalizeProjectName,
  rankProjectSuggestions,
  shouldShowCreateProjectOption,
} from '../project-popover'

function project(id: string, name: string, overrides: Partial<Project> = {}): Project {
  return {
    id,
    name,
    color: null,
    description: null,
    archivedAt: null,
    createdAt: new Date('2026-01-01T00:00:00Z'),
    updatedAt: new Date('2026-01-01T00:00:00Z'),
    ...overrides,
  }
}

const names = (suggestions: Array<{ name: string }>) => suggestions.map((s) => s.name)

describe('normalizeProjectName', () => {
  it('앞뒤 공백을 걷어내고 소문자로 비교한다 — DB의 유일 인덱스와 같은 기준', () => {
    expect(normalizeProjectName('  AWC ')).toBe('awc')
  })
})

describe('rankProjectSuggestions', () => {
  it('입력이 없으면 최근에 만든 것 먼저 보여준다', () => {
    const projects = [
      project('a', '오래된', { createdAt: new Date('2026-01-01T00:00:00Z') }),
      project('b', '최근', { createdAt: new Date('2026-06-01T00:00:00Z') }),
    ]

    expect(names(rankProjectSuggestions({ allProjects: projects, query: '' }))).toEqual([
      '최근',
      '오래된',
    ])
  })

  it('입력이 있으면 부분 일치로 좁히고 앞부분 일치를 먼저 둔다', () => {
    const projects = [project('a', 'my-awc'), project('b', 'awc-crm'), project('c', '다른것')]

    expect(names(rankProjectSuggestions({ allProjects: projects, query: 'awc' }))).toEqual([
      'awc-crm',
      'my-awc',
    ])
  })

  it('대소문자를 가리지 않는다', () => {
    const projects = [project('a', 'AWC')]

    expect(names(rankProjectSuggestions({ allProjects: projects, query: 'aw' }))).toEqual(['AWC'])
  })

  it('보관된 프로젝트는 목록에서 빠진다 — 끝난 것에 새로 담지 않는다', () => {
    const projects = [
      project('a', '진행중'),
      project('b', '끝난것', { archivedAt: new Date('2026-05-01T00:00:00Z') }),
    ]

    expect(names(rankProjectSuggestions({ allProjects: projects, query: '' }))).toEqual(['진행중'])
  })

  it('이미 지정된 프로젝트는 체크로 표시한다 — 다시 눌러 해제할 수 있어야 한다', () => {
    const projects = [project('a', 'AWC'), project('b', '다른것')]

    const result = rankProjectSuggestions({
      allProjects: projects,
      assignedProjectId: 'a',
      query: '',
    })

    expect(result.find((s) => s.id === 'a')?.assigned).toBe(true)
    expect(result.find((s) => s.id === 'b')?.assigned).toBe(false)
  })

  it('보관된 프로젝트라도 지금 그 노트에 지정돼 있으면 보여준다 — 안 보이면 해제할 길이 없다', () => {
    const projects = [project('b', '끝난것', { archivedAt: new Date('2026-05-01T00:00:00Z') })]

    const result = rankProjectSuggestions({
      allProjects: projects,
      assignedProjectId: 'b',
      query: '',
    })

    expect(names(result)).toEqual(['끝난것'])
    expect(result[0].assigned).toBe(true)
  })
})

describe('shouldShowCreateProjectOption', () => {
  it('입력한 이름이 아직 없으면 그 자리에서 만들 수 있게 한다', () => {
    expect(shouldShowCreateProjectOption({ allProjects: [project('a', 'AWC')], query: '새것' })).toBe(
      true
    )
  })

  it('대소문자만 다른 같은 이름이면 만들지 않는다 — DB가 어차피 거부한다', () => {
    expect(shouldShowCreateProjectOption({ allProjects: [project('a', 'AWC')], query: ' awc ' })).toBe(
      false
    )
  })

  it('빈 입력에는 만들기 줄을 띄우지 않는다', () => {
    expect(shouldShowCreateProjectOption({ allProjects: [], query: '   ' })).toBe(false)
  })

  it('보관된 프로젝트와 같은 이름도 만들지 않는다 — 유일 인덱스는 보관 여부를 보지 않는다', () => {
    const archived = project('a', 'AWC', { archivedAt: new Date('2026-05-01T00:00:00Z') })

    expect(shouldShowCreateProjectOption({ allProjects: [archived], query: 'awc' })).toBe(false)
  })
})
