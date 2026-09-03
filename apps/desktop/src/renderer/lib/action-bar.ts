/**
 * 액션 줄을 **글쇠로** 고른다 (BRU-213).
 *
 * 마우스를 올렸을 때 뜨는 그 툴바를 `/`로 띄우고 방향키로 옮겨 다닌다. 새 UI를
 * 만들지 않는 것이 요점이다 — 버튼도, 그림도, 눌렀을 때 하는 일도 이미 있다.
 * 여기서 하는 일은 **어느 버튼에 초점을 둘지**를 정하는 것뿐이고, 화면에 뜨는
 * 것은 `.note-card-actions:focus-within`이 알아서 한다.
 *
 * 그래서 `data-hint`도 공짜로 따라온다: HintLayer는 focusin을 듣고 있어서,
 * 방향키로 버튼에 닿는 순간 마우스를 올렸을 때와 같은 설명·글쇠가 뜬다.
 */

/** 다음에 고를 자리. 끝에서는 반대편으로 돈다. 버튼이 없으면 -1. */
export function rovingIndex(current: number, count: number, delta: number): number {
  if (count <= 0) return -1
  return (current + delta + count) % count
}

export type ActionBarKeyResult = { type: 'move'; delta: number } | { type: 'close' } | null

/**
 * 액션 줄이 떠 있는 동안의 글쇠 해석.
 *
 * Enter·Space는 **일부러 null이다** — 버튼이 초점을 들고 있으니 브라우저가
 * 알아서 누른다. 여기서 가로채면 클릭 경로가 둘로 갈리고, 그중 하나는
 * 언젠가 뒤처진다.
 */
export function resolveActionBarKey(key: string): ActionBarKeyResult {
  if (key === 'ArrowRight' || key === 'ArrowDown') return { type: 'move', delta: 1 }
  if (key === 'ArrowLeft' || key === 'ArrowUp') return { type: 'move', delta: -1 }
  if (key === 'Escape') return { type: 'close' }
  return null
}
