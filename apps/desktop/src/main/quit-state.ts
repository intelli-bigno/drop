// 앱이 "진짜 종료 중"인지를 한 곳에서 관리한다.
// macOS에서 창 닫기는 기본적으로 숨기기(메뉴바 앱)지만,
// 종료 중일 때는 실제로 닫혀야 앱이 죽고 업데이트 설치가 진행된다.

let quitting = false

export function isQuitting(): boolean {
  return quitting
}

export function markQuitting(): void {
  quitting = true
}

// 테스트 전용 — 프로덕션 코드에서는 호출하지 않는다.
export function resetQuitState(): void {
  quitting = false
}

export function shouldHideOnClose(platform: NodeJS.Platform, quittingNow: boolean): boolean {
  return platform === 'darwin' && !quittingNow
}
