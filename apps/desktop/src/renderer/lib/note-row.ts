// 노트 행에 무엇이 남는가 (BRU-187).
//
// 재설계 전에는 메타데이터가 오른쪽 열에 쌓였다. 그 열은 액션 8개가 들어갈
// 206px을 상시 예약했고(BRU-57), 평소에는 시간 55px만 써서 실측 159px이 늘 비어
// 있었다. 그 구조를 걷어내면서, 무엇을 본문 흐름 안으로 옮길지가 아니라
// **무엇을 행에서 아예 뺄지**로 결정이 옮겨 갔다 (2026-08-30 bruce).
//
// 남은 것은 셋뿐이다:
//   상태칸(할일 체크박스) · 본문 · Linear 반출 배지
//
// 뺀 것과 그것이 간 곳:
//   프로젝트·태그·우선순위 → 미리보기 패널(Space)
//   핀                   → PINNED 그룹 헤더
//   잠금                 → 본문 자리의 '잠긴 노트' placeholder
//   댓글·첨부·링크 카운트   → 없앴다. 첨부가 있는지는 열어야 안다 (감수한 대가)
//   액션 8개             → hover 시 떠 있는 툴바 (행에 자리를 잡지 않는다)

import type { NoteViewMode } from '../stores/notes/types'

export type TrailingAdornment = 'export'

export interface RowAdornmentInput {
  viewMode: NoteViewMode
  isTodo: boolean
  isExported: boolean
}

export interface RowAdornments {
  /** 본문 x를 한 줄로 맞추기 위해 상태칸을 항상 비워 두는가 */
  reservesStatusSlot: boolean
  /** 상태칸에 체크박스를 그리는가 (할일, 활성 뷰) */
  showsCheckbox: boolean
  /**
   * 상태칸에 노트 아이콘을 그리는가.
   * 칸을 비워 두면 목록 왼쪽이 이가 빠진 것처럼 보인다 — brxce도 모든 행에
   * 타입 아이콘을 둔다. 체크박스와 같은 칸을 쓰므로 둘은 배타적이다.
   */
  showsNoteIcon: boolean
  trailing: TrailingAdornment[]
  /** 오른쪽에 미리 비워 둘 폭. 재설계 후에는 언제나 0이다 */
  reservedTrailingWidth: number
}

export function resolveRowAdornments(input: RowAdornmentInput): RowAdornments {
  const isActive = input.viewMode === 'active'

  const trailing: TrailingAdornment[] = []
  // 기본 목록에서는 반출된 노트가 빠져 있어, 이 배지는 '반출된 노트 보기'를 켠
  // 목록에서 주로 보인다. 그 목록에서는 어느 이슈로 나갔는지가 곧 그 줄의 존재 이유다.
  if (input.isExported) trailing.push('export')

  const showsCheckbox = isActive && input.isTodo

  return {
    // 노트와 할일이 섞인 목록에서 본문이 한 줄로 맞으려면 노트에도 자리가 필요하다.
    reservesStatusSlot: true,
    showsCheckbox,
    // 체크박스가 안 들어가는 자리는 노트 아이콘이 채운다 —
    // 휴지통·보관함의 할일도 여기로 온다.
    showsNoteIcon: !showsCheckbox,
    trailing,
    // 액션은 hover에 떠 있는 툴바로 뜨고 자리를 잡지 않는다 — BRU-57의 예약을 없앴다.
    reservedTrailingWidth: 0,
  }
}
