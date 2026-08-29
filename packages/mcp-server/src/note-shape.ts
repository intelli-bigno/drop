/**
 * RPC가 돌려주는 노트 행의 모양 (BRU-183).
 *
 * 왜 모으는가 — 이 파일이 생기기 전에는 `Note` 행 인터페이스가 `notes.ts`·`tags.ts`·
 * `search.ts`에 **세 벌 따로** 선언돼 있었다. 컬럼이 하나 늘 때마다 세 곳을 똑같이
 * 고쳐야 하고, 한 곳만 빠뜨리면 그 파일의 툴에서만 필드가 사라진다 — BRU-67에서
 * 카테고리 플래그가 클라이언트 여러 곳에 흩어져 어긋났던 것과 같은 모양이다.
 *
 * **행 타입만** 모은다. 행→응답 매핑은 합치지 않았다: 다섯 툴의 응답 shape이 원래부터
 * 서로 다르기 때문이다(검색은 `matchedText`만 붙이고 `hasLink`조차 싣지 않는다,
 * 날짜 검색은 `createdAtKst`, 태그 조회는 축소판). 공통분은 네 필드뿐이라 뽑아 봐야
 * 얻는 게 없고, 억지로 합치면 응답이 조용히 바뀐다.
 */

/**
 * RPC 노트 행.
 *
 * 좁은 `SELECT` 목록을 쓰는 함수가 있어(`mcp_get_notes_by_tag`·`mcp_search_notes`·
 * `mcp_search_by_date_range`) 모든 함수가 함께 싣는 것만 필수로 두고 나머지는
 * 선택적이다. 필수/선택 구분이 곧 "어느 RPC에서나 믿고 읽어도 되는 필드"의 정의다.
 */
export interface NoteRow {
  id: string
  display_id: number
  content: string
  created_at: string
  has_link: boolean
  has_media: boolean
  has_files: boolean
  /** 노트의 종류 (BRU-175). 'note' | 'todo' */
  type?: string | null
  /** 할일을 끝낸 시각 (BRU-175). null이면 미완료 */
  completed_at?: string | null
  source?: string
  parent_id?: string | null
  is_locked?: boolean
  updated_at?: string
  deleted_at?: string | null
  archived_at?: string | null
  linear_issue_url?: string | null
  linear_issue_key?: string | null
  linear_exported_at?: string | null
  tags?: Array<{ id: string; name: string }>
  attachments?: Array<{
    id: string
    type: string
    filename: string | null
    mime_type: string | null
    size: number | null
    storage_path?: string | null
  }>
}

/**
 * 타입·완료를 응답 모양으로 옮긴다 (BRU-175).
 *
 * `type`이 비어 있으면 `'note'`로 넘어뜨린다 — 갱신되지 않은 RPC나 백필 이전 행이
 * 섞여 들어와도 `undefined`가 에이전트에게 새지 않는다. 데스크톱 `noteRowToNote`와
 * 같은 규칙이다.
 */
export function toTodoFields(row: NoteRow) {
  return {
    type: row.type ?? 'note',
    completedAt: row.completed_at ?? null,
  }
}
