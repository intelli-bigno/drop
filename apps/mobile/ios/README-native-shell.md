# 네이티브 셸 (BRU-160) — 딥링크 · 공유 확장 · 홈 위젯

Flutter 앱(`apps/mobile`)의 iOS 네이티브 껍데기. `apps/ios`(SwiftUI 앱)의
DropShare·DropWidget을 스펙으로 이식했다.

## 구조

| 경로 | 내용 |
| --- | --- |
| `DropShare/` | 공유 확장. App Group `inbox/`에 **적어 두기만** 하고, 앱이 켜질 때 비운다 |
| `DropWidget/` | 홈 위젯 4종(최근 노트·새 노트·카메라·갤러리). App Group의 `widget-snapshot.json`만 읽는다 |
| `DropShell/` | 두 확장이 공유하는 이식 조각 — SharedInbox 쓰기, WidgetSnapshot 읽기, 웜 페이퍼 토큰 인라인 |
| `Runner/NativeShellChannel.swift` | MethodChannel `drop/native_shell` — App Group 경로 조회·위젯 리로드 **둘만** 넘긴다 |
| `scripts/add_native_targets.rb` | 확장 타깃 배선의 정본(xcodeproj gem, 멱등). pbxproj를 손으로 고치지 않는다 |

파싱·스냅샷 규칙은 전부 drop_core(순수 Dart)에 있고 `dart test`가 덮는다:
`shared_inbox.dart` · `widget_snapshot.dart` · `drop_link.dart`. Swift 쪽
(`DropShell/DropShellCore.swift`)과의 계약은 snake_case JSON 키 + ISO8601 시각.

## 타깃 구성 (스크립트가 만든다)

- 번들 ID: `com.intellieffect.drop.mobile.share` / `.widget` — `apps/ios`의
  확장과 동일. App Group도 동일: `group.com.intellieffect.drop.shared`.
- 버전·빌드 번호: base config를 `Flutter/Generated.xcconfig`로 걸고
  `MARKETING_VERSION=$(FLUTTER_BUILD_NAME)`, `CURRENT_PROJECT_VERSION=$(FLUTTER_BUILD_NUMBER)` —
  앱과 확장의 버전이 어긋나면 App Store가 거부한다.
- 배포 타깃: 확장 17.0 (`containerBackground` 필요), 앱 15.0
  (ITMS-90068 — 2027 봄부터 15.0+ 필수, BRU-160에서 상향).
- **임베드 순서**: `Embed Foundation Extensions`는 Flutter `Thin Binary`
  스크립트보다 앞이어야 한다. 뒤에 서면 `Cycle inside Runner`로 빌드가 죽는다.
  스크립트가 순서를 강제한다.

## CI / 서명이 알아야 할 것 (BRU-161 트랙)

1. **App Store 아카이브에는 확장 프로파일 2종이 더 필요하다.** 번들 ID가
   `apps/ios` 확장과 같으므로 기존 프로파일을 그대로 쓴다
   (`scripts/mobile-export-options.plist`에 매핑 반영됨):
   - `com.intellieffect.drop.mobile.share` → `DROP Native Share App Store`
   - `com.intellieffect.drop.mobile.widget` → `DROP-Widget-Provisioning-Profile`
   - 매핑이나 프로파일 임포트가 빠지면 appex가 entitlements 없이 서명되어
     TestFlight 업로드가 409로 막힌다 (BRU-58 재발 방지).
2. release.yml의 프로파일 시크릿 임포트 단계에 위 2종 프로파일을 함께 설치해야
   한다 — `apps/ios` 네이티브 빌드가 쓰던 것과 같은 파일이다.
3. `DEVELOPMENT_TEAM`: Runner pbxproj는 `LU65TLHW3Q`(로컬 개발용)로 남아 있다.
   아카이브는 manual signing + export options(`teamID J2Y925QHNV`)라 영향이
   없지만, 자동 서명으로 바꿀 일이 있으면 팀부터 맞출 것.

## 로컬 검증

```sh
make mobile-test mobile-analyze          # drop_core + 앱 (에뮬레이터 불필요)
cd apps/mobile && flutter build ios --simulator --dart-define=DROP_PREVIEW=true
ls build/ios/iphonesimulator/Runner.app/PlugIns   # DropShare.appex, DropWidget.appex
```

타깃 배선을 다시 만들려면: `cd apps/mobile/ios && ruby scripts/add_native_targets.rb`
(재실행 안전).
