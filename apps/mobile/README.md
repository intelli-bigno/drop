# DROP Mobile (Flutter)

DROP의 모바일 앱 — **Flutter 재구축 트랙 (BRU-152)**. 옛 Flutter 앱(BRU-22에서 제거)의 복원이 아니라, **현재 `apps/ios` 네이티브 구현 상태를 스펙으로** 처음부터 재구축한다. 번복 경위·원칙은 Linear 프로젝트 「DROP Flutter 재구축」.

`apps/ios`·`apps/android`(네이티브)는 이 앱이 패리티에 도달할 때까지 유지된다.

## 구조

```
apps/mobile/
  packages/drop_core/    # 도메인 로직 — Flutter SDK 의존 0, `dart test`로 검증
  lib/                   # 앱: 화면 조립 + 플랫폼 배선
  .config/               # make mobile-config 생성물 (커밋 금지)
```

**로직은 drop_core에 둔다.** 에뮬레이터 없이 테스트가 도는 상태를 유지하는 것이 레포 TDD 사이클(Red → Green → Refactor)의 전제다 — `apps/ios/Packages/DropCore`와 같은 규율이고, **그쪽 Swift 테스트 스위트가 포팅 스펙**이다.

## 명령 (레포 루트에서)

| 명령 | 설명 |
| --- | --- |
| `make mobile-config` | `.env.local` → `.config/{local,remote}.json` 생성 |
| `make mobile-test` | drop_core `dart test` + 앱 위젯 테스트 (에뮬레이터 불필요) |
| `make mobile-analyze` | dart analyze (drop_core + 앱) |
| `make mobile-dev` / `mobile-dev-remote` | 시뮬레이터에서 실행 (로컬 / 리모트 Supabase) |
| `make mobile-build` | iOS 시뮬레이터용 빌드 |
| `make mobile-clean` | 생성물 정리 |

## 자격증명 없이 띄우기 — 프리뷰 모드

```
flutter run --dart-define=DROP_PREVIEW=true
```

`.config/*.json`(자격증명) 없이 뜬다 — 인증을 건너뛰고 인메모리 표본(`lib/preview/preview_launch.dart`, iOS `PreviewLaunch.swift` 포팅)을 쓴다. iOS의 `-dropPreview` 실행 인자 대응. **화면 확인·UI 이슈(BRU-156~)의 실측 경로가 이것이다** — 네트워크·DB 없음.

## 디자인 토큰·테마 (BRU-159)

색·간격·타이포의 정본은 `design-system/drop/tokens.json` 하나다. `make tokens`(레포 루트)가 `lib/theme/drop_tokens.g.dart`를 생성한다 — **생성물은 커밋한다** (빌드가 Node에 의존하지 않게, iOS Swift·Android Kotlin과 같은 규율. CI는 `make tokens-check`).

- `lib/theme/drop_tokens.g.dart` — 생성물. 라이트·다크 색 한 벌씩(`DropTokenColors.light/.dark`) + 간격·모서리·글자 크기. **직접 고치지 마라.**
- `lib/theme/drop_theme.dart` — 손으로 쓰는 의미 계층 (iOS `DropUI/DropTheme.swift` 대응). 토큰 → `ThemeData`(웜 페이퍼), `DropColors.of(context)`(현재 모드의 토큰), `DropSpacing`·`DropRadius`, 표면 역할(`surfacePage`·`surfaceCard`·`surfaceSelected`·`surfaceField`).
- **화면에 리터럴 색(`Colors.*`, `Color(0x…)`)을 적지 않는다.** `test/design_system_audit_test.dart`(iOS `DesignSystemAuditTests` 포팅)가 소스를 읽어 잡는다.

## 구성값이 흐르는 경로

```
.env.local → make mobile-config → .config/{local,remote}.json
  → flutter run --dart-define-from-file=.config/local.json
  → lib/config.dart (String.fromEnvironment)
  → drop_core DropConfiguration (검증 — 누락·스킴 잘림·웹=iOS 클라이언트 ID 중복을 즉시 실패)
  → lib/environment/bootstrap.dart → DropEnvironmentContainer (Riverpod 주입)
```

구성이 틀리면 시작 시점에 즉시 죽는다 — 잘못된 구성으로 실행을 이어가면 "로그인이 안 된다" 같은 엉뚱한 증상으로 나타난다 (iOS와 같은 규율).

## 배포 (BRU-161)

릴리스 파이프라인(`.github/workflows/release.yml`)의 모바일 레인은 **이 앱을 빌드한다** — 네이티브(`apps/ios`·`apps/android`)는 CI 테스트로만 남고 릴리스는 나가지 않는다.

| 레인 | 경로 | 산출 |
| --- | --- | --- |
| `release-ios` | `flutter build ipa --no-codesign` → `xcodebuild -exportArchive`(수동 서명, `scripts/mobile-export-options.plist`) → `xcrun altool` | TestFlight |
| `release-android` | `flutter build apk/appbundle --release` (keystore 시크릿 서명 + SHA-1 지문 대조) | Firebase App Distribution (+ Play internal, 시크릿 있을 때만) |

- **실행**: 태그 `v*` push(데스크톱 포함 전체 릴리스) 또는 검증 빌드만 `gh workflow run release.yml -f target=ios|android`.
- **버전**: iOS 빌드 번호 `date -u +%y%m%d%H%M`(과거 앱 레코드보다 커야 함), Android versionCode는 2025-01-01 이후 "분"(Play 상한 2,100,000,000 이하). 태그 릴리스면 버전 문자열도 태그에서.
- **구성값**: CI가 시크릿으로 `scripts/mobile-config.sh` → `.config/remote.json`을 만들어 `--dart-define-from-file`로 주입 — 로컬 개발과 같은 경로다.
- **iOS 서명**: 아카이브는 무서명, export 단계에서 수동 프로파일(`DROP Native App Store`, 번들 ID가 네이티브와 같아 재사용)로 서명한다 — Xcode 프로젝트의 팀 설정에 의존하지 않는다. ExportOptions가 `apps/mobile/ios/`가 아니라 `scripts/`에 있는 이유는 plist 안의 주석 참조. **공유 확장·위젯(BRU-160)이 추가되면** share/widget 프로파일 임포트와 plist 매핑을 되살려야 한다 (BRU-58 참조).
- **Android 서명**: `android/app/build.gradle.kts`가 `ANDROID_KEYSTORE_FILE` 등 환경변수를 읽어 릴리스 키로 서명. 환경변수 없으면 debug 키 폴백 — 그 빌드는 Google 로그인이 안 된다(SHA-1 불일치).

## 주의

- **번들 ID `com.intellieffect.drop.mobile`** — 과거 Flutter 앱 시절의 App Store Connect 레코드·TestFlight를 그대로 승계한다. 빌드 번호는 그 시절보다 커야 하므로 시간 기반.
- **`GOOGLE_WEB_CLIENT_ID`(serverClientId) 필수** — Supabase Google provider는 웹 클라이언트 하나만 audience로 신뢰한다. 빼면 `Unacceptable audience` (PR #17 실증).
- **iOS 빌드는 CocoaPods 경로를 쓴다** — Flutter 3.44의 SwiftPM 통합은 이 환경에서 `Could not resolve package dependencies`로 죽는다 (2026-08-27 실측). `flutter config --no-enable-swift-package-manager`가 머신 전역 설정이라 새 머신에서는 한 번 실행해야 한다.
- 로컬 빌드에 `DEVELOPER_DIR` 지정이 필요할 수 있다 (`xcode-select`가 CommandLineTools를 가리키는 머신).
