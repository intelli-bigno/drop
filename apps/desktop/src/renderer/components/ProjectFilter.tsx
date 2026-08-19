import { useMemo } from 'react'
import { useNotesStore } from '../stores/notes'
import { UNASSIGNED_PROJECT_ID } from '../lib/note-filters'
import { Icon } from './Icon'

/**
 * 프로젝트별 필터 (BRU-83).
 *
 * 보관된 프로젝트는 목록에 띄우지 않는다 — 지금 보고 있는 것이 아니면 자리만 차지한다.
 * 다만 지금 그 프로젝트로 보고 있다면 남긴다(해제할 길이 있어야 한다).
 *
 * "미분류"는 목록 맨 끝에 둔다. 프로젝트가 하나도 없으면 셀렉트 자체를 띄우지 않는다 —
 * 고를 것이 없는 필터는 헤더 자리만 먹는다.
 */
export function ProjectFilter() {
  const allProjects = useNotesStore((s) => s.allProjects)
  const filterProjectId = useNotesStore((s) => s.filterProjectId)
  const setFilterProject = useNotesStore((s) => s.setFilterProject)

  const visibleProjects = useMemo(
    () => allProjects.filter((p) => !p.archivedAt || p.id === filterProjectId),
    [allProjects, filterProjectId]
  )

  if (visibleProjects.length === 0) return null

  return (
    <div className="project-filter">
      <span className="project-filter-icon" aria-hidden="true">
        <Icon name="folder" size={13} />
      </span>
      <select
        className="project-filter-select"
        aria-label="프로젝트 필터"
        value={filterProjectId ?? ''}
        onChange={(e) => setFilterProject(e.target.value || null)}
      >
        <option value="">모든 프로젝트</option>
        {visibleProjects.map((project) => (
          <option key={project.id} value={project.id}>
            {project.name}
          </option>
        ))}
        <option value={UNASSIGNED_PROJECT_ID}>미분류</option>
      </select>
    </div>
  )
}
