// 답글 계층의 들여쓰기 가이드 (BRU-190).
//
// brxce의 `IndentationGuides`를 그대로 가져왔다 (VS Code식). 원본과 다른 점은
// 색 하나뿐이다 — brxce는 깊이가 곧 노드 타입(goal/project/task)이라 무지개 5색을
// 쓰지만, DROP의 답글은 타입이 아니라 그냥 중첩이라 색을 넣으면 없는 의미를
// 지어내는 셈이다. 그래서 `--border-color` 단색으로 간다.
//
// 전에는 자식 카드에 `border-left: 2px`를 그리는 게 전부였다. 그 선은 자기 행
// 높이(33px)만큼만 있는 토막이라 형제가 연속해도 하나의 척추로 이어지지 않았고,
// 조상 열이 없어 깊이 2 이상에서는 몇 단인지 셀 수도 없었다.
//
// 핵심은 선을 **레이아웃 밖의 레이어**로 두는 것이다. 들여쓰기는 행의 왼쪽
// 패딩이 하고, 선은 여기가 절대 배치로 그린다. 그래야 `top: 0; bottom: 0`으로
// 행 전체를 채워 형제 행끼리 자연히 이어진다.

// 한 단 들여쓰기 폭은 lib/note-indent.ts가 정본이다 (BRU-197).
// 레일 간격과 카드 안쪽 패딩이 같은 수에서 나와야 어긋나지 않는다.
export { TREE_INDENT } from '../lib/note-indent'
import { TREE_INDENT } from '../lib/note-indent'

/** 레일이 서는 x — 들여쓰기 칸 안에서 상태칸 중심과 맞춘 위치. */
export const TREE_RAIL_OFFSET = 22

interface Props {
  /** 들여쓰기 단수. 0이면 그릴 것이 없다 */
  depth: number
}

export function NoteTreeGuides({ depth }: Props) {
  if (depth <= 0) return null

  return (
    <span className="note-tree-guides" aria-hidden="true">
      {Array.from({ length: depth }).map((_, level) => (
        <span
          key={level}
          className="note-tree-rail"
          style={{ left: `${level * TREE_INDENT + TREE_RAIL_OFFSET}px` }}
        />
      ))}
    </span>
  )
}
