# DROP iOS (네이티브)

DROP의 모바일 앱. SwiftUI 네이티브 단일 트랙 — Flutter 앱(`apps/mobile`)은 BRU-22에서 제거됐고, 코드는 그 삭제 커밋 이전 git 히스토리에 남아 있다. 전환 경위는 Linear 프로젝트 **DROP iOS 네이티브 전환**(BRU-6 ~ BRU-22).

## 구조

```
apps/ios/
  project.yml            # 프로젝트 정의의 SoT — .xcodeproj는 여기서 생성한다
  Drop/                  # 앱 타겟: @main, 화면 조립, Info.plist, 에셋
  DropShare/             # 공유 시트 확장 — App Group에 적어 두고 앱이 비운다
  DropWidget/            # 홈 화면 위젯 — 앱이 적어 둔 요약(WidgetSnapshot)만 읽는다
  Packages/
    DropCore/            # 도메인 로직 — UIKit/SwiftUI 의존 0, `swift test`로 검증
    DropUI/              # 공용 뷰 · 디자인 토큰 (SwiftUI 의존 허용)
```

**로직은 DropCore에 둔다.** 시뮬레이터 없이 테스트가 도는 상태를 유지하는 것이 레포의 TDD 사이클(Red → Green → Refactor) 전제다. 앱 타겟에는 조립만 남긴다.

## 명령

| 명령 | 설명 |
| --- | --- |
| `make ios-config` | 환경변수 → `Config/Config-*.xcconfig` 생성 |
| `make ios-test` | DropCore 테스트 (시뮬레이터 불필요, 가장 빠른 피드백) |
| `make ios-build` / `ios-build-remote` | 시뮬레이터용 빌드 (로컬 / 리모트 Supabase) |
| `make ios-dev` / `ios-dev-remote` | 시뮬레이터에서 실행 |
| `make ios-open` | Xcode로 열기 |
| `make ios-clean` | 생성물 정리 |

사전 준비: `brew install xcodegen`, Xcode 설치, 그리고 **`make ios-config`** 1회.

## 구성값이 흐르는 경로

```
.env.local 또는 export한 환경변수
  → scripts/ios-config.sh
  → apps/ios/Config/Config-{localdev,remote}.xcconfig   (gitignore)
  → 빌드 설정 → Info.plist ($(SUPABASE_URL) 등)
  → DropConfiguration (검증) → DropEnvironmentContainer → SupabaseClient
```

환경변수 이름은 과거 Flutter 타겟과 같다 (`SUPABASE_URL_LOCAL` / `SUPABASE_ANON_KEY_LOCAL` / `SUPABASE_URL_REMOTE` / `SUPABASE_ANON_KEY_REMOTE`) — 기존 `.env.local`을 그대로 재사용한다.

**xcconfig는 `//`부터를 주석으로 잘라먹는다.** URL은 `https:/$()/host` 형태로 써야 스킴이 살아남는다(`$()`는 빌드 시 빈 문자열). 생성 스크립트가 자동으로 처리하고, 그래도 스킴이 잘린 값이 들어오면 `DropConfiguration`이 `malformedURL`로 즉시 실패시킨다 — 조용히 잘못 붙는 경우는 없다.

빌드 구성은 셋이다: `Debug-localdev`, `Debug-remote`, `Release-remote`. 스킴 `Drop-localdev` / `Drop-remote`가 각각을 실행하고, 아카이브는 둘 다 `Release-remote`를 쓴다.

## 규칙

- **`Drop.xcodeproj`는 커밋하지 않는다.** `project.yml`이 SoT이고 `make ios-generate`가 프로젝트를 만든다 — pbxproj 머지 충돌을 없애기 위한 선택. Xcode에서 파일을 추가해도 디렉토리 구조만 맞으면 재생성 시 반영된다.
- **로컬 빌드에는 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`가 필요하다** (`xcode-select`가 CommandLineTools를 가리키고 있다). Makefile 타겟은 이미 넘긴다.
- **번들 ID는 `com.intellieffect.drop.mobile`이다.** 과거 Flutter 앱이 쓰던 것을 그대로 이어받았다(BRU-21/PR #36) — App Group·App Store Connect 레코드·TestFlight 테스터가 유지된다. 빌드 번호는 그 시절 것보다 커야 하므로 CI가 시간 기반으로 만든다.
- 최소 배포 타겟 **iOS 17.0** (`@Observable` 사용 조건).
