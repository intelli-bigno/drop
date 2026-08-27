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

## 주의

- **번들 ID `com.intellieffect.drop.mobile`** — 과거 Flutter 앱 시절의 App Store Connect 레코드·TestFlight를 그대로 승계한다. 빌드 번호는 그 시절보다 커야 하므로 시간 기반.
- **`GOOGLE_WEB_CLIENT_ID`(serverClientId) 필수** — Supabase Google provider는 웹 클라이언트 하나만 audience로 신뢰한다. 빼면 `Unacceptable audience` (PR #17 실증).
- **iOS 빌드는 CocoaPods 경로를 쓴다** — Flutter 3.44의 SwiftPM 통합은 이 환경에서 `Could not resolve package dependencies`로 죽는다 (2026-08-27 실측). `flutter config --no-enable-swift-package-manager`가 머신 전역 설정이라 새 머신에서는 한 번 실행해야 한다.
- 로컬 빌드에 `DEVELOPER_DIR` 지정이 필요할 수 있다 (`xcode-select`가 CommandLineTools를 가리키는 머신).
