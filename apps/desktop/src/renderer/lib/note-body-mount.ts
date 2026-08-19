import type { NoteCardView } from './note-edit-mode'

/**
 * 펼쳐진 카드의 **무거운 본문**(뷰어·첨부·링크 프리뷰)을 지금 마운트할지 (BRU-79).
 *
 * 왜 조건이 필요한가: 피드에는 가상화가 없고 노트 조회에 상한도 없다 — 노트 전량이
 * 항상 DOM에 있다. 전체 펼치기 토글 한 번에 N개의 뷰어와 N개의 첨부 목록과 N개의
 * 링크 프리뷰가 동시에 마운트되면, 첨부마다 서명 URL 발급이, YouTube URL마다
 * oEmbed 조회가 한꺼번에 나간다. 노트 수백 건이면 요청 수백~수천 건이다.
 *
 * 그래서 **뷰포트에 들어온 카드만** 본문을 마운트한다. 비용이 목록 길이가 아니라
 * 화면 크기에 비례하게 된다.
 *
 * `hasEnteredViewport`는 **한 번 참이면 되돌리지 않는다**(sticky). 화면 밖으로
 * 나갔다고 언마운트하면 위쪽 카드가 접히면서 스크롤이 튄다 — 그리고 다시 볼 때
 * 요청을 또 내야 한다. 늘어나기만 하는 편이 둘 다 없다.
 */
export interface NoteBodyMountInput {
  view: NoteCardView
  /** 이 카드가 한 번이라도 뷰포트(여유 폭 포함)에 들어왔는가 */
  hasEnteredViewport: boolean
  /** 피드에서 포커스를 받고 있는가 */
  isFocused: boolean
}

export function shouldMountNoteBody({
  view,
  hasEnteredViewport,
  isFocused,
}: NoteBodyMountInput): boolean {
  // 접혀 있으면 애초에 본문이 없다
  if (view === 'one-line') return false
  // 포커스·편집은 관측을 기다리지 않는다 — 방금 넘어온 카드가 한 박자 늦게 뜨면
  // j/k가 끊긴 것처럼 느껴진다
  if (view === 'editor' || isFocused) return true
  return hasEnteredViewport
}
