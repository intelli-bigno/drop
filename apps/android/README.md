# DROP Android (네이티브)

Flutter 앱(`apps/mobile`)을 대체하는 Jetpack Compose 네이티브 트랙. 진행은 Linear 트랙 **BRU-36**(하위: BRU-38 ~ BRU-42).

## 구조

```
apps/android/
  settings.gradle.kts      # 모듈 구성
  gradle/libs.versions.toml # 버전 카탈로그 (의존성 버전의 SoT)
  core/                    # 도메인 로직 — Android SDK 의존 0, `:core:test`로 검증
  app/                     # 앱 모듈: Compose 화면 조립, Manifest, BuildConfig
```

**로직은 `core`에 둔다.** 에뮬레이터·Android SDK 없이 테스트가 도는 상태를 유지하는 것이 레포의 TDD 사이클(Red → Green → Refactor) 전제다. `app`에는 조립만 남긴다. iOS의 `DropCore` / `Drop` 분리와 같은 구조이고, 같은 도메인 규칙을 같은 이름으로 옮겼다:

| iOS (`DropCore`) | Android (`core`) |
| --- | --- |
| `Note` / `Tag` / `Attachment` | 같음 |
| `NoteAssembler.assemble` / `.sorted` | 같음 |
| `NotesStore` (`@Observable`) | `NotesStore` + `NotesState` (`StateFlow`) |
| `NotesRepository` 프로토콜 | `NotesRepository` 인터페이스 |
| `InMemoryNotesRepository` | 같음 |

## 명령

| 명령 | 설명 |
| --- | --- |
| `make android-config` | 환경변수 → `apps/android/local.properties` 생성 |
| `make android-test` | `core` JVM 테스트 (에뮬레이터 불필요, 가장 빠른 피드백) |
| `make android-build` | 디버그 APK 빌드 |
| `make android-install` | 연결된 기기·에뮬레이터에 설치 |
| `make android-clean` | 생성물 정리 |

사전 준비: JDK 17 이상, Android SDK(platform 35), 그리고 **`make android-config`** 1회.

## 구성값이 흐르는 경로

```
.env.local 또는 export한 환경변수
  → scripts/android-config.sh
  → apps/android/local.properties        (gitignore)
  → app/build.gradle.kts
  → BuildConfig.SUPABASE_URL / BuildConfig.SUPABASE_ANON_KEY
```

우선순위는 **환경변수 > gradle 속성(`-P`, `gradle.properties`) > `local.properties`** 다. CI는 환경변수만 넣는다.

환경변수 이름은 Flutter·iOS 타겟과 같다 (`SUPABASE_URL_LOCAL` / `SUPABASE_ANON_KEY_LOCAL` / `SUPABASE_URL_REMOTE` / `SUPABASE_ANON_KEY_REMOTE`) — 기존 `.env.local`을 그대로 재사용한다.

에뮬레이터에서 호스트의 로컬 Supabase는 `127.0.0.1`이 아니라 **`10.0.2.2`** 로 보인다. `android-config.sh`의 local 기본값이 그것이다.

## 규칙

- **`core`에 Android 의존을 넣지 않는다.** 넣는 순간 `:core:test`가 에뮬레이터·SDK를 요구하게 되고, TDD 사이클이 느려진다.
- **비밀값은 커밋하지 않는다.** `local.properties`는 gitignore 대상이고, 커밋되는 것은 `local.properties.example`뿐이다.
- **`applicationId`는 병렬 운영 기간 동안 `com.intellieffect.drop.android`다.** Flutter 앱이 `com.intellieffect.drop.mobile`을 쓰고 있어, 같은 ID를 쓰면 한 기기에 두 앱을 동시에 설치할 수 없다.
- 최소 SDK **26** (`java.time`을 desugaring 없이 쓸 수 있는 하한).
- Gradle toolchain을 고정하지 않는다 — 고정하면 해당 JDK가 없는 기계에서 다운로드부터 막힌다. 산출 바이트코드만 17에 맞춘다.

## 아직 없는 것

BRU-38은 **스캐폴드까지**다. 다음은 별도 이슈에서 붙인다.

- 로그인 / 세션 (BRU-39) — Android OAuth 클라이언트를 `bruce-clawdbot` GCP 프로젝트로 옮기는 것이 선행 조건이다.
- 실제 Supabase 노트 CRUD (BRU-40)
- 태그·첨부 (BRU-41)
- Play Console 배포 (BRU-42) — 서명 키와 Play 서비스 계정 자격증명이 필요하다.
