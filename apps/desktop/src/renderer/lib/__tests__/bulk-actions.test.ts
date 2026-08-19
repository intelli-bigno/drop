import { describe, it, expect } from 'vitest'
import {
  bulkActionsForViewMode,
  buildBulkDeleteConfirmMessage,
  tagIdsOnEveryNote,
} from '../bulk-actions'

describe('bulkActionsForViewMode', () => {
  // 액션 세트는 iOS SelectionActionBar(BRU-15)와 맞춘다 —
  // 휴지통에서 "보관"은 뜻이 없고, 활성 뷰에서 "복원"도 마찬가지다.
  it('shouldOfferArchiveAndTrashInTheActiveView', () => {
    expect(bulkActionsForViewMode('active')).toEqual(['tag', 'archive', 'trash'])
  })

  it('shouldOfferUnarchiveAndTrashInTheArchivedView', () => {
    expect(bulkActionsForViewMode('archived')).toEqual(['unarchive', 'trash'])
  })

  it('shouldOfferRestoreAndPermanentDeleteInTheTrashView', () => {
    expect(bulkActionsForViewMode('trash')).toEqual(['restore', 'deletePermanently'])
  })

  // 태그는 활성 뷰에서만 — 휴지통 안의 노트를 분류하는 일은 없다
  it('shouldNotOfferTaggingOutsideTheActiveView', () => {
    expect(bulkActionsForViewMode('archived')).not.toContain('tag')
    expect(bulkActionsForViewMode('trash')).not.toContain('tag')
  })
})

describe('buildBulkDeleteConfirmMessage', () => {
  it('shouldSayHowManyNotesGoToTheTrash', () => {
    const message = buildBulkDeleteConfirmMessage(4, 'trash')
    expect(message).toContain('4개')
    expect(message).toContain('휴지통으로 이동')
  })

  // 영구 삭제는 되돌릴 수 없다 — 문구가 달라야 한다
  it('shouldWarnThatPermanentDeleteCannotBeUndone', () => {
    const message = buildBulkDeleteConfirmMessage(2, 'deletePermanently')
    expect(message).toContain('2개')
    expect(message).toContain('영구 삭제')
    expect(message).toContain('복원할 수 없습니다')
  })
})

describe('tagIdsOnEveryNote', () => {
  const note = (...tagIds: string[]) => ({ tags: tagIds.map((id) => ({ id })) })

  // 전부에 달린 태그만 "붙어 있음"으로 본다 — 다시 누르면 전부에서 뗀다
  it('shouldKeepOnlyTagsSharedByTheWholeSelection', () => {
    expect(tagIdsOnEveryNote([note('a', 'b'), note('b', 'c')])).toEqual(['b'])
  })

  it('shouldReturnEveryTagForASingleNote', () => {
    expect(tagIdsOnEveryNote([note('a', 'b')]).sort()).toEqual(['a', 'b'])
  })

  it('shouldReturnNothingWhenNothingIsShared', () => {
    expect(tagIdsOnEveryNote([note('a'), note('b')])).toEqual([])
  })

  it('shouldReturnNothingForAnEmptySelection', () => {
    expect(tagIdsOnEveryNote([])).toEqual([])
  })
})
