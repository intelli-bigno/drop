# DROP Android (네이티브)

Jetpack Compose 네이티브 Android 앱. 진행은 Linear 트랙 **BRU-36**(하위: BRU-38 ~ BRU-42).

Android 빌드는 Flutter 앱(`apps/mobile`)이 하던 일이었고, 그 앱은 BRU-22에서 제거됐다. 이 모듈이 그 자리를 네이티브로 다시 채운다.

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
  → BuildConfig.SUPABASE_URL / BuildConfig.SUPABASE_ANON_KEY / BuildConfig.GOOGLE_WEB_CLIENT_ID
```

우선순위는 **환경변수 > gradle 속성(`-P`, `gradle.properties`) > `local.properties`** 다. CI는 환경변수만 넣는다.

환경변수 이름은 iOS 타겟과 같다 (`SUPABASE_URL_LOCAL` / `SUPABASE_ANON_KEY_LOCAL` / `SUPABASE_URL_REMOTE` / `SUPABASE_ANON_KEY_REMOTE`) — 기존 `.env.local`을 그대로 재사용한다.

에뮬레이터에서 호스트의 로컬 Supabase는 `127.0.0.1`이 아니라 **`10.0.2.2`** 로 보인다. `android-config.sh`의 local 기본값이 그것이다.

`GOOGLE_WEB_CLIENT_ID`는 Google 로그인의 `serverClientId`이고 **웹** 클라이언트 ID여야 한다 — Supabase Google provider가 audience로 신뢰하는 것이 웹 클라이언트 하나뿐이라, Android 클라이언트 ID를 넣으면 `Unacceptable audience`로 거부된다. OAuth 클라이언트 ID는 비밀값이 아니라(APK에 그대로 실린다) `android-config.sh`가 실제 값을 기본값으로 들고 있다.

## Google 로그인이 되려면 (GCP 쪽 선행 조건)

Google은 호출 앱을 `(패키지명, 서명 SHA-1)`로 매칭한다. `bruce-clawdbot` 프로젝트에 그 조합의 Android OAuth 클라이언트가 **등록돼 있어야** 로그인 창이 id_token을 돌려준다. `google-services.json`은 이 매칭에 관여하지 않는다 (BRU-30에서 실측 확인).

| 빌드 | 서명 SHA-1 | 클라이언트 등록 |
| --- | --- | --- |
| release | `A8:D1:12:55:A3:31:4B:C8:A8:1D:59:13:D4:43:2A:4A:01:78:60:17` | 등록됨 (`627053596385-m1ooh…`) |
| debug (`~/.android/debug.keystore`) | `6B:45:06:0A:EA:62:47:E6:88:82:3A:4E:14:FA:24:1E:93:96:96:82` | **미등록 — 로컬 디버그 빌드는 로그인이 막힌다** (BRU-30) |

디버그 클라이언트는 콘솔에서 사람이 만들어야 한다 (GCP에 OAuth 클라이언트 생성 API가 없다).

## 배포 (BRU-42)

```bash
gh workflow run release.yml -f target=android    # 태그 없이 테스터 빌드만
```

태그(`v*`)를 밀면 데스크톱·iOS와 함께 나간다.

| 경로 | 상태 |
| --- | --- |
| Firebase App Distribution (`testers` 그룹, APK) | **동작한다** — `FIREBASE_ANDROID_APP_ID` · `FIREBASE_SERVICE_ACCOUNT` 시크릿이 이미 있다 |
| Play 내부 테스트 (AAB) | `PLAY_SERVICE_ACCOUNT_JSON` 시크릿이 들어오면 자동으로 함께 나간다. 없으면 경고를 남기고 건너뛴다 |

- 서명 값은 **환경변수 → `key.properties`** 순으로 찾는다(`local.properties`와 분리 — 구성값과 키스토어 비밀번호를 한 파일에 두지 않는다). 둘 다 커밋되지 않는다.
- 키스토어가 없는 기계에서는 릴리스 빌드가 **디버그 키로** 서명된다. 서명 설정을 비워 두면 `app-release-unsigned.apk`가 나와 설치조차 안 되기 때문이다. 대신 CI가 `apksigner`로 지문을 대조해, 릴리스 키가 아닌 빌드는 배포 전에 끊는다 — 지문이 어긋난 빌드는 **로그인만 실패하는 빌드**가 된다.
- `versionCode`는 CI가 "2025-01-01 이후 분"으로 만든다. iOS와 같은 `yyMMddHHmm`은 **Play 상한(2,100,000,000)을 넘어서** 쓸 수 없다.

## 규칙

- **`core`에 Android 의존을 넣지 않는다.** 넣는 순간 `:core:test`가 에뮬레이터·SDK를 요구하게 되고, TDD 사이클이 느려진다.
- **비밀값은 커밋하지 않는다.** `local.properties`는 gitignore 대상이고, 커밋되는 것은 `local.properties.example`뿐이다.
- **`applicationId`는 `com.intellieffect.drop.mobile`이다** — 과거 Flutter 앱이 쓰던 ID를 그대로 이어받았다 (iOS가 번들 ID를 이어받은 것과 같은 판단, BRU-39에서 확정). 스캐폴드 단계(BRU-38)에서는 `…drop.android`였다. 바꾼 이유는 **Google 로그인**이다: Google은 호출 앱을 `(패키지명, 서명 SHA-1)`로만 매칭하므로, `bruce-clawdbot`에 이미 등록된 Android OAuth 클라이언트를 쓰려면 그 조합이어야 한다. Play 등록·테스터도 이 ID에 붙어 있다.
- 최소 SDK **26** (`java.time`을 desugaring 없이 쓸 수 있는 하한).
- Gradle toolchain을 고정하지 않는다 — 고정하면 해당 JDK가 없는 기계에서 다운로드부터 막힌다. 산출 바이트코드만 17에 맞춘다.

## 아직 없는 것

로그인·세션(BRU-39)까지 왔다. 다음은 별도 이슈에서 붙인다.

- 실제 Supabase 노트 CRUD (BRU-40) — 지금 로그인 뒤 목록은 인메모리 표본이다.
- 태그·첨부 (BRU-41)
- Play Console 배포 (BRU-42) — 서명 키와 Play 서비스 계정 자격증명이 필요하다.
