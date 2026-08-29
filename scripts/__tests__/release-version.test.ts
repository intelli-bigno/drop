// 릴리스 버전 계산 (BRU-192).
//
// 이 로직이 없던 시절 `make release`는 `apps/desktop/package.json`에서 patch를 올렸다.
// 그런데 릴리스 버전의 정본은 **태그**다 — release.yml이 `VERSION=${GITHUB_REF#refs/tags/v}`로
// 태그에서 뽑아 package.json을 덮어쓴다. 그래서 커밋된 package.json 값은 아무도 관리하지
// 않은 채 0.0.9에 머물렀고, 태그는 v1.0.34까지 갔다.
//
// 그 상태로 `make release`를 돌리면 v0.0.10을 만들려 한다. 그건 이미 존재하는 옛 태그이고,
// 설령 없었더라도 **최신보다 낮은 버전**이라 설치본 자동 업데이트가 조용히 멈춘다
// (electron-updater는 semver 역행을 무시한다 — 실패가 눈에 띄지 않는다).
//
// 그래서 계산의 근거를 태그로 옮기고, 역행을 구조로 막는다.

import { describe, expect, it } from 'vitest'
import { latestVersion, nextPatchVersion, assertMovesForward } from '../release-version.mjs'

describe('latestVersion', () => {
  it('semver 순으로 가장 높은 것을 고른다 — 사전순이 아니다', () => {
    // 사전순이면 v1.0.9가 v1.0.34보다 뒤에 온다. 그 함정이 이 이슈의 뿌리다.
    expect(latestVersion(['v1.0.9', 'v1.0.34', 'v1.0.7'])).toBe('1.0.34')
  })

  it('메이저·마이너도 숫자로 비교한다', () => {
    expect(latestVersion(['v0.0.10', 'v1.0.2', 'v0.9.99'])).toBe('1.0.2')
  })

  it('v 접두어가 없어도 읽는다', () => {
    expect(latestVersion(['1.0.3', 'v1.0.4'])).toBe('1.0.4')
  })

  it('semver가 아닌 태그는 무시한다', () => {
    expect(latestVersion(['nightly', 'v1.0.4', 'release-candidate'])).toBe('1.0.4')
  })

  it('태그가 하나도 없으면 null이다 — 호출부가 판단하게 둔다', () => {
    expect(latestVersion([])).toBeNull()
    expect(latestVersion(['nightly'])).toBeNull()
  })
})

describe('nextPatchVersion', () => {
  it('patch를 하나 올린다', () => {
    expect(nextPatchVersion('1.0.34')).toBe('1.0.35')
  })

  it('두 자리 이상에서도 올바르게 올린다', () => {
    expect(nextPatchVersion('1.0.99')).toBe('1.0.100')
  })

  it('첫 릴리스는 0.0.1이다', () => {
    expect(nextPatchVersion(null)).toBe('0.0.1')
  })
})

describe('assertMovesForward', () => {
  it('앞으로 가면 통과한다', () => {
    expect(() => assertMovesForward('1.0.35', '1.0.34')).not.toThrow()
  })

  // 이 가드가 이 이슈의 핵심이다. 없으면 낮은 버전이 조용히 발행된다.
  it('같거나 낮으면 멈춘다', () => {
    expect(() => assertMovesForward('1.0.34', '1.0.34')).toThrow(/역행|같/)
    expect(() => assertMovesForward('0.0.10', '1.0.34')).toThrow(/역행|같/)
  })

  it('사전순으로는 커 보이지만 semver로 낮은 경우도 잡는다', () => {
    // '1.0.9' > '1.0.34' (사전순) 이지만 semver로는 낮다
    expect(() => assertMovesForward('1.0.9', '1.0.34')).toThrow(/역행|같/)
  })

  it('첫 릴리스는 비교 대상이 없으므로 통과한다', () => {
    expect(() => assertMovesForward('0.0.1', null)).not.toThrow()
  })
})
