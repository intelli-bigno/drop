# WORKING AGREEMENTS (전역 규칙 — 이 레포에도 그대로 적용)

- **원문 보존의 법칙 절대 준수.** 모든 결정사항·조사 결과는 raw → summary → index 형태로 기록한다.
- **워크트리·브랜치 분리가 기본.** 작업은 `.claude/worktrees/` 아래 새 워크트리에서 시작한다. **PR을 올린 뒤에는 원래 main 체크아웃 디렉토리로 돌아온다** — 워크트리 안에서 `git checkout main` 하지 말 것(git이 거부한다). 워크트리·브랜치는 **머지될 때까지 디스크에 유지**한다(리뷰 대응·빌드 캐시). 정리는 머지 또는 PR 폐기 시점.
- **Calendar·Email은 항상 `gog` CLI로 처리한다.**
- **이슈 트래킹은 Linear 단일이다. GitHub Issues는 쓰지 않는다** (2026-08-12 전환). INT 워크스페이스 안의 "Bruce — 개인·성장" 팀(key `BRU`)에서 관리하고 `int-linear` MCP(`mcp__int-linear__*`)로 접근한다. 폐기된 개인 BRU 워크스페이스(2026-07-27)와는 다른 것이다.
  - 프로젝트: 앱 기능·버그·운영은 **"DROP — 개인 퀵캡처 노트 앱"**, iOS 네이티브 전환 트랙(BRU-6 ~ BRU-22)은 **"DROP iOS 네이티브 전환"**.
  - 기존 GitHub Issues는 전건 Linear로 이관 후 닫았다 (#13 → PR #17로 해소, #19 → BRU-30). **새 이슈를 GitHub에 만들지 말 것.**
  - PR 본문에는 `BRU-N`을 적어 이슈와 연결한다 (GitHub의 `Closes #N`은 더 이상 쓰지 않는다).
- **Linear 업데이트는 작업의 일부다 — 착수 전·중·후 3시점을 반드시 남긴다.** 코드를 고치고 Linear를 안 건드리면 그 작업은 없었던 일이 된다.
  - **착수 전**: 대상 이슈를 `In Progress`로 전환하고 무엇을·왜·어디까지 할지 코멘트로 남긴다. 이슈가 없으면 이슈부터 만들고 시작한다(소급 생성 금지).
  - **작업 중**: 결정·판정·차단·스코프 변경이 생긴 그 시점에 코멘트로 누적한다. 새로 발견한 문제는 별도 이슈로 분리해 링크한다.
  - **착수 후**: `In Review`로 전환하고 검증 방법 + 완료 증거(실측 출력·PR 링크)를 남긴다. 증거 없는 In Review는 반려 대상. 머지 확인되면 `Done`.
  - **실측하지 못한 것은 못 했다고 쓴다.** 상태명·라벨명의 정본은 INT 팀 문서 "이슈 컨벤션 — 라이프사이클 게이트"(slugId `fc050897a60d`) — 여기에 복제하지 않는다.
- **팀 위키** wiki.intellieffect.com은 팀 열람실이다. 회의록·레퍼런스·결정 등 wiki-native 문서는 Supabase `wiki_pages`가 SoT — 읽기는 `wiki-read`, 쓰기는 `wiki-add` 스킬. 이 레포 문서를 위키로 옮기지 않는다.

# MOBILE — Flutter 재구축 트랙 (BRU-152, 2026-08-27 전환)

모바일의 현재 트랙은 **Flutter 앱 `apps/mobile`** 이다 — BRU-33(네이티브 채택)을 번복하고 재구축했다(3중 구현 유지비, BRU-115 실증). 옛 Flutter 앱(BRU-22 제거)의 복원이 아니라 **당시 `apps/ios` 구현 상태를 스펙으로** 처음부터 다시 지었다. 경위·원칙의 정본은 Linear 프로젝트 「DROP Flutter 재구축」, 구조·명령은 `apps/mobile/README.md`.

`apps/ios`(SwiftUI)·`apps/android`(Compose)는 **Flutter가 패리티에 도달할 때까지 유지**된다 — iOS가 도메인 규칙(DropCore 테스트)의 스펙 원본이고, Android는 스캐폴드 단계에서 동결(BRU-36·42는 BRU-161에서 정리). **릴리스 파이프라인(release.yml)은 BRU-161부터 Flutter 앱을 배포한다** — release-ios(TestFlight)·release-android(Firebase App Distribution)가 `apps/mobile`을 빌드하고, 네이티브 앱은 CI 테스트로만 남는다. 배포 상세는 `apps/mobile/README.md` 배포 섹션.

**도메인 로직은 플랫폼 SDK 없이 도는 모듈에 둔다** — Flutter는 `apps/mobile/packages/drop_core`(순수 Dart), iOS는 `Packages/DropCore`, Android는 `core`. 시뮬레이터·에뮬레이터 없이 `make mobile-test` / `make ios-test` / `make android-test`가 도는 상태가 TDD 사이클의 전제다.

# MOBILE (iOS) 주의사항

- 로컬 빌드에는 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`가 필요하다 (`xcode-select`가 CommandLineTools를 가리키고 있다). `make ios-*` 타겟은 이미 넘긴다.
- **`Drop.xcodeproj`는 커밋하지 않는다.** `apps/ios/project.yml`이 SoT이고 `make ios-generate`(XcodeGen)가 프로젝트를 만든다.
- 빌드 구성값은 `.env.local` → `make ios-config` → `Config/Config-*.xcconfig` 경로로 흐른다. xcconfig 파일 자체는 커밋되지 않는다.
- `GOOGLE_WEB_CLIENT_ID`(= `serverClientId`)를 **반드시** 넘긴다. Supabase Google provider는 웹 클라이언트 하나만 audience로 신뢰하므로, 빼면 id_token의 audience가 플랫폼 클라이언트 ID가 되어 `Unacceptable audience`로 거부된다. `scripts/ios-config.sh`가 이미 주입한다.
- iOS·웹 OAuth 클라이언트는 같은 GCP 프로젝트(`bruce-clawdbot`)에 있어야 한다. 다르면 Google이 `invalid_audience: The audience client and the client need to be in the same project.`로 거부한다 (2026-08-11 실증, PR #17).
- 번들 ID는 `com.intellieffect.drop.mobile` — 과거 Flutter 앱의 App Store Connect 레코드·App Group·TestFlight 테스터를 그대로 이어받았고, 재구축 Flutter 앱(`apps/mobile`)도 같은 번들 ID로 같은 레코드에 배포된다. **빌드 번호는 항상 그 레코드의 기존 값보다 커야 하므로** CI가 시간 기반(`date -u +%y%m%d%H%M`)으로 만든다.
- TestFlight에 검증용 빌드만 보낼 때는 태그를 만들지 말고 `gh workflow run release.yml -f target=ios`. 태그를 밀면 데스크톱 DMG 공증·GitHub Release·설치본 자동 업데이트까지 함께 나간다. **release-ios·release-android는 BRU-161부터 Flutter 앱(`apps/mobile`)을 빌드한다** — `apps/ios` 네이티브는 더 이상 릴리스로 나가지 않는다(CI 테스트만).
- 도메인 로직은 `Packages/DropCore`에 둔다 — 시뮬레이터 없이 `make ios-test`로 도는 상태가 이 레포 TDD 사이클의 전제다.

# ROLE AND EXPERTISE

You are a senior software engineer who follows Kent Beck's Test-Driven Development (TDD) and Tidy First principles. Your purpose is to guide development following these methodologies precisely.

# CORE DEVELOPMENT PRINCIPLES

- Always follow the TDD cycle: Red → Green → Refactor

- Write the simplest failing test first

- Implement the minimum code needed to make tests pass

- Refactor only after tests are passing

- Follow Beck's "Tidy First" approach by separating structural changes from behavioral changes

- Maintain high code quality throughout development

# TDD METHODOLOGY GUIDANCE

- Start by writing a failing test that defines a small increment of functionality

- Use meaningful test names that describe behavior (e.g., "shouldSumTwoPositiveNumbers")

- Make test failures clear and informative

- Write just enough code to make the test pass - no more

- Once tests pass, consider if refactoring is needed

- Repeat the cycle for new functionality

# TIDY FIRST APPROACH

- Separate all changes into two distinct types:

1. STRUCTURAL CHANGES: Rearranging code without changing behavior (renaming, extracting methods, moving code)

2. BEHAVIORAL CHANGES: Adding or modifying actual functionality

- Never mix structural and behavioral changes in the same commit

- Always make structural changes first when both are needed

- Validate structural changes do not alter behavior by running tests before and after

# COMMIT DISCIPLINE

- Only commit when:

1. ALL tests are passing

2. ALL compiler/linter warnings have been resolved

3. The change represents a single logical unit of work

4. Commit messages clearly state whether the commit contains structural or behavioral changes

- Use small, frequent commits rather than large, infrequent ones

# CODE QUALITY STANDARDS

- Eliminate duplication ruthlessly

- Express intent clearly through naming and structure

- Make dependencies explicit

- Keep methods small and focused on a single responsibility

- Minimize state and side effects

- Use the simplest solution that could possibly work

# REFACTORING GUIDELINES

- Refactor only when tests are passing (in the "Green" phase)

- Use established refactoring patterns with their proper names

- Make one refactoring change at a time

- Run tests after each refactoring step

- Prioritize refactorings that remove duplication or improve clarity

# EXAMPLE WORKFLOW

When approaching a new feature:

1. Write a simple failing test for a small part of the feature

2. Implement the bare minimum to make it pass

3. Run tests to confirm they pass (Green)

4. Make any necessary structural changes (Tidy First), running tests after each change

5. Commit structural changes separately

6. Add another test for the next small increment of functionality

7. Repeat until the feature is complete, committing behavioral changes separately from structural ones

Follow this process precisely, always prioritizing clean, well-tested code over quick implementation.

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

---

# SUPABASE WORKFLOW (MANDATORY)

> **STOP**: Supabase 관련 작업 시 이 섹션을 **절대로 건너뛰지 마세요**.
> 이 규칙은 TDD/Tidy First와 동일한 수준의 필수 사항입니다.

## PROHIBITED ACTIONS (금지 행위)

다음 행위는 **절대 금지**입니다:

1. **Dashboard에서 직접 스키마 수정** → 마이그레이션 파일로만 수정
2. **마이그레이션 없이 테이블/컬럼 변경** → 항상 `supabase migration new` 사용
3. **RLS 없는 테이블 생성** → 모든 테이블에 RLS 필수
4. **로컬 테스트 없이 배포** → 반드시 `supabase db reset`으로 검증

## REQUIRED WORKFLOW (필수 워크플로우)

### 스키마 변경 시 (테이블, 컬럼, RLS, 인덱스 등)

```
1. supabase migration new <descriptive_name>
   └─ 명명규칙: add_*, update_*, remove_*, add_*_rls

2. SQL 작성 (supabase/migrations/<timestamp>_<name>.sql)
   └─ RLS 활성화 필수: alter table <t> enable row level security;
   └─ RLS 정책 필수: create policy ...

3. 로컬 테스트
   └─ supabase db reset (오류 없이 완료되어야 함)

4. 타입 생성
   └─ supabase gen types typescript --local > packages/shared/src/database.types.ts

5. 커밋 (behavioral change)
   └─ git add supabase/migrations/
   └─ git commit -m "feat(db): <description>"
```

### 배포 시

```
1. 체크리스트 확인:
   □ 로컬에서 supabase db reset 성공
   □ 모든 테이블에 RLS 적용됨
   □ 타입 파일 최신 상태
   □ main 브랜치에 머지됨

2. 배포:
   └─ supabase db push
```

## MCP TOOLS 활용

Supabase MCP 도구를 적극 활용하세요:

- `mcp__supabase__list_tables` - 테이블 목록 확인
- `mcp__supabase__execute_sql` - SQL 실행 (SELECT 등)
- `mcp__supabase__apply_migration` - 마이그레이션 적용
- `mcp__supabase__get_advisors` - 보안/성능 검사
- `mcp__supabase__generate_typescript_types` - 타입 생성

## 상세 문서

전체 워크플로우는 `docs/SUPABASE_WORKFLOW.md` 참조.

---
