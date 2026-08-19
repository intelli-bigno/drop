// 프로젝트 타입 (BRU-83 `projects`).
//
// 노트를 묶는 상위 분류다. 태그와는 다른 축이고, 노트는 프로젝트 **하나**에만 속한다
// (`notes.project_id`). 이름은 사람이 적은 그대로 보관한다 — 태그와 달리 소문자로 뭉개지 않는다.
// 중복 판정만 소문자·trim 기준이고, 그 기준은 DB의 유일 인덱스와 같다.

export interface ProjectRow {
  id: string
  user_id: string
  name: string
  color: string | null
  description: string | null
  archived_at: string | null
  created_at: string
  updated_at: string
}

export interface Project {
  id: string
  name: string
  color: string | null
  description: string | null
  /** 끝난 프로젝트. 목록에서 접히지만 노트는 그대로 매달려 있다 */
  archivedAt: Date | null
  createdAt: Date
  updatedAt: Date
}

export function projectRowToProject(row: ProjectRow): Project {
  return {
    id: row.id,
    name: row.name,
    color: row.color,
    description: row.description,
    archivedAt: row.archived_at ? new Date(row.archived_at) : null,
    createdAt: new Date(row.created_at),
    updatedAt: new Date(row.updated_at),
  }
}
