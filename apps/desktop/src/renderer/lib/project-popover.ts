// 노트에 프로젝트를 지정하는 팝오버(BRU-83)의 순수 규칙.
//
// 태그 팝오버와 모양은 같지만 규칙이 둘 다르다:
// 1) 노트는 프로젝트 **하나**에만 속한다 — 고르면 닫힌다. 연달아 여러 개를 달 일이 없다.
// 2) 이름을 소문자로 뭉개지 않는다 — 사람이 적은 대로 보관한다. 중복 판정만 소문자·trim이고,
//    그 기준은 DB의 유일 인덱스 `(user_id, lower(btrim(name)))`와 같다.

import type { Project } from '@drop/shared'

/** 중복·검색 비교용 정규형. 저장되는 이름은 이 함수를 거치지 않는다 */
export function normalizeProjectName(name: string): string {
  return name.trim().toLowerCase()
}

export interface ProjectSuggestion {
  id: string
  name: string
  color: string | null
  /** 이 노트에 이미 지정된 프로젝트인가 — 체크로 보이고 다시 누르면 해제한다 */
  assigned: boolean
}

export interface RankProjectSuggestionsInput {
  allProjects: Project[]
  /** 이 노트에 지금 지정된 프로젝트 id */
  assignedProjectId?: string | null
  query: string
  limit?: number
}

const DEFAULT_LIMIT = 8

/**
 * 팝오버에 보여줄 프로젝트 목록.
 *
 * 1. 보관된 프로젝트는 뺀다 — 끝난 것에 새로 담지 않는다.
 *    단, 지금 그 노트에 지정돼 있으면 남긴다. 안 보이면 해제할 길이 없다.
 * 2. 입력이 있으면 부분 일치(대소문자 무시)로 좁히고 앞부분 일치를 먼저 둔다
 * 3. 그다음은 최근에 만든 것 먼저 — 새로 만든 프로젝트가 지금 쓰는 프로젝트다
 * 4. 그래도 같으면 이름 순
 */
export function rankProjectSuggestions({
  allProjects,
  assignedProjectId = null,
  query,
  limit = DEFAULT_LIMIT,
}: RankProjectSuggestionsInput): ProjectSuggestion[] {
  const normalizedQuery = normalizeProjectName(query)

  const matched = allProjects.filter((project) => {
    if (project.archivedAt && project.id !== assignedProjectId) return false
    return !normalizedQuery || normalizeProjectName(project.name).includes(normalizedQuery)
  })

  const prefixRank = (project: Project) =>
    normalizedQuery && normalizeProjectName(project.name).startsWith(normalizedQuery) ? 0 : 1

  const sorted = [...matched].sort((a, b) => {
    const byPrefix = prefixRank(a) - prefixRank(b)
    if (byPrefix !== 0) return byPrefix

    const byCreated = b.createdAt.getTime() - a.createdAt.getTime()
    if (byCreated !== 0) return byCreated

    return a.name.localeCompare(b.name)
  })

  return sorted.slice(0, limit).map((project) => ({
    id: project.id,
    name: project.name,
    color: project.color,
    assigned: project.id === assignedProjectId,
  }))
}

export interface ShouldShowCreateProjectOptionInput {
  allProjects: Project[]
  query: string
}

/**
 * 입력한 이름의 프로젝트가 아직 없으면 그 자리에서 만들 수 있게 한다.
 *
 * 보관된 프로젝트도 같은 이름으로 친다 — 유일 인덱스는 보관 여부를 보지 않으므로
 * 만들기를 띄워 봐야 DB가 거부한다.
 */
export function shouldShowCreateProjectOption({
  allProjects,
  query,
}: ShouldShowCreateProjectOptionInput): boolean {
  const normalized = normalizeProjectName(query)
  if (!normalized) return false
  return !allProjects.some((project) => normalizeProjectName(project.name) === normalized)
}
