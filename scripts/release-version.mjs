#!/usr/bin/env node
/**
 * 릴리스 버전 계산 (BRU-192).
 *
 * ## 버전의 정본은 태그다
 *
 * `.github/workflows/release.yml`이 태그에서 버전을 뽑아 package.json을 덮어쓴다:
 *
 *     VERSION=${GITHUB_REF#refs/tags/v}
 *     npm version $VERSION --no-git-tag-version --allow-same-version
 *
 * 그래서 **커밋된 `apps/desktop/package.json`의 version은 배포에 쓰이지 않는다.** 빌드 시점에
 * 태그 값으로 덮어써진다. 그 값을 정본으로 착각하고 거기서 patch를 올리던 것이 이 이슈다 —
 * 아무도 관리하지 않아 0.0.9에 머물러 있었고, 태그는 v1.0.34까지 가 있었다.
 *
 * ## 왜 역행 가드가 필요한가
 *
 * 낮은 버전이 발행돼도 **아무도 실패를 못 본다.** electron-updater는 `latest-mac.yml`의
 * 버전이 설치본보다 낮으면 조용히 무시한다 — 릴리스는 성공한 것처럼 보이고 아무도
 * 업데이트를 못 받는다. 그래서 계산 단계에서 막는다.
 *
 * ## 쓰는 곳
 *
 *     node scripts/release-version.mjs next     # 다음 patch 버전 (가드 통과 시)
 *     node scripts/release-version.mjs latest   # 현재 최신 릴리스 버전
 *
 * Makefile의 `release`·`release-local`이 둘 다 이걸 쓴다 — 두 경로가 같은 답을 보게
 * 하는 것이 목적이다. 전에는 `release-local`이 package.json을 읽어 태그도 없이
 * `--publish always`로 낮은 버전을 올릴 수 있었다.
 */

import { execFileSync } from 'node:child_process'

const SEMVER = /^v?(\d+)\.(\d+)\.(\d+)$/

/** `1.2.3` → `[1, 2, 3]`. semver가 아니면 null. */
function parse(tag) {
  const m = SEMVER.exec(tag.trim())
  if (!m) return null
  return [Number(m[1]), Number(m[2]), Number(m[3])]
}

function compare(a, b) {
  for (let i = 0; i < 3; i += 1) {
    if (a[i] !== b[i]) return a[i] - b[i]
  }
  return 0
}

/**
 * 태그 목록에서 가장 높은 릴리스 버전. semver가 아닌 태그는 무시한다.
 *
 * **숫자로 비교한다.** 사전순으로 정렬하면 `v1.0.9`가 `v1.0.34`보다 뒤에 와서
 * 최신을 잘못 고른다 — 이 이슈가 나온 자리와 같은 종류의 함정이다.
 *
 * @param {string[]} tags
 * @returns {string | null} `1.0.34` 꼴, 없으면 null
 */
export function latestVersion(tags) {
  const parsed = tags.map(parse).filter(Boolean)
  if (parsed.length === 0) return null
  const top = parsed.reduce((best, cur) => (compare(cur, best) > 0 ? cur : best))
  return top.join('.')
}

/**
 * 다음 patch 버전. 최신이 없으면(첫 릴리스) `0.0.1`.
 * @param {string | null} latest
 */
export function nextPatchVersion(latest) {
  if (!latest) return '0.0.1'
  const v = parse(latest)
  if (!v) throw new Error(`읽을 수 없는 버전: ${latest}`)
  return [v[0], v[1], v[2] + 1].join('.')
}

/**
 * 다음 버전이 최신보다 **앞으로 가는지** 확인한다. 아니면 던진다.
 *
 * 자동 업데이트는 semver 역행을 조용히 무시하므로, 여기서 막지 않으면
 * "릴리스는 성공했는데 아무도 업데이트를 못 받는" 상태가 된다.
 *
 * @param {string} next
 * @param {string | null} latest
 */
export function assertMovesForward(next, latest) {
  if (!latest) return
  const a = parse(next)
  const b = parse(latest)
  if (!a || !b) throw new Error(`읽을 수 없는 버전: ${next} / ${latest}`)
  if (compare(a, b) <= 0) {
    throw new Error(
      `버전이 역행하거나 같다: ${next} ≤ ${latest}\n` +
        '자동 업데이트는 역행을 조용히 무시한다 — 발행해도 아무도 받지 못한다.'
    )
  }
}

/** 로컬 태그를 읽는다. 릴리스는 main에서만 하므로 fetch는 호출부(Makefile)가 한다. */
function readTags() {
  const out = execFileSync('git', ['tag', '--list', 'v*'], { encoding: 'utf8' })
  return out.split('\n').filter(Boolean)
}

// CLI — 테스트가 import할 때는 돌지 않는다
if (process.argv[1] && process.argv[1].endsWith('release-version.mjs')) {
  const mode = process.argv[2] ?? 'next'
  const latest = latestVersion(readTags())

  if (mode === 'latest') {
    if (!latest) {
      console.error('✗ 릴리스 태그가 하나도 없다')
      process.exit(1)
    }
    process.stdout.write(latest)
  } else if (mode === 'next') {
    const next = nextPatchVersion(latest)
    try {
      assertMovesForward(next, latest)
    } catch (error) {
      console.error(`✗ ${error.message}`)
      process.exit(1)
    }
    process.stdout.write(next)
  } else {
    console.error(`✗ 알 수 없는 모드: ${mode} (next | latest)`)
    process.exit(1)
  }
}
