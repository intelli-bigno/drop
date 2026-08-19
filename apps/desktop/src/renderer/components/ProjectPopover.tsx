import { useCallback } from 'react'
import { useNotesStore } from '../stores/notes'
import { CardPopover, type CardPopoverItem } from './CardPopover'
import { rankProjectSuggestions, shouldShowCreateProjectOption } from '../lib/project-popover'

interface Props {
  noteId: string
  /** 이 노트에 지금 지정된 프로젝트 id */
  projectId: string | null
  onClose: () => void
}

const CREATE_ITEM_ID = '__create__'

/**
 * 노트에 프로젝트를 지정하는 팝오버 (BRU-83).
 *
 * 태그 팝오버와 달리 고르면 닫힌다 — 노트는 프로젝트 하나에만 속하므로
 * 연달아 고를 일이 없다. 이미 지정된 것을 다시 누르면 해제된다.
 */
export function ProjectPopover({ noteId, projectId, onClose }: Props) {
  const allProjects = useNotesStore((s) => s.allProjects)
  const createProject = useNotesStore((s) => s.createProject)
  const setNoteProject = useNotesStore((s) => s.setNoteProject)

  const buildItems = useCallback(
    (query: string): CardPopoverItem[] => {
      const items: CardPopoverItem[] = rankProjectSuggestions({
        allProjects,
        assignedProjectId: projectId,
        query,
      }).map((s) => ({
        id: s.id,
        label: s.name,
        prefix: '◆',
        checked: s.assigned,
      }))

      if (shouldShowCreateProjectOption({ allProjects, query })) {
        items.push({
          id: CREATE_ITEM_ID,
          label: `"${query.trim()}" 프로젝트 만들기`,
          isCreate: true,
        })
      }

      return items
    },
    [allProjects, projectId]
  )

  const handleSelect = useCallback(
    async (item: CardPopoverItem, query: string) => {
      if (item.isCreate) {
        const project = await createProject(query)
        if (project) await setNoteProject(noteId, project.id)
        return
      }
      // 지정된 것을 다시 누르면 해제 — 프로젝트를 잘못 골랐을 때 되돌리는 유일한 길
      await setNoteProject(noteId, item.checked ? null : item.id)
    },
    [noteId, createProject, setNoteProject]
  )

  return (
    <CardPopover
      ariaLabel="프로젝트 지정"
      placeholder="프로젝트 검색 또는 생성..."
      emptyLabel="프로젝트가 없습니다 — 이름을 입력하면 새로 만듭니다"
      buildItems={buildItems}
      onSelect={handleSelect}
      onClose={onClose}
    />
  )
}
