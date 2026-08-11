# DROP iOS (네이티브)

Flutter 앱(`apps/mobile`)을 대체하는 SwiftUI 네이티브 트랙. 진행은 Linear 프로젝트 **DROP iOS 네이티브 전환**(BRU-6 ~ BRU-22).

## 구조

```
apps/ios/
  project.yml            # 프로젝트 정의의 SoT — .xcodeproj는 여기서 생성한다
  Drop/                  # 앱 타겟: @main, 화면 조립, Info.plist, 에셋
  Packages/
    DropCore/            # 도메인 로직 — UIKit/SwiftUI 의존 0, `swift test`로 검증
    DropUI/              # 공용 뷰 · 디자인 토큰 (SwiftUI 의존 허용)
```

**로직은 DropCore에 둔다.** 시뮬레이터 없이 테스트가 도는 상태를 유지하는 것이 레포의 TDD 사이클(Red → Green → Refactor) 전제다. 앱 타겟에는 조립만 남긴다.

## 명령

| 명령 | 설명 |
| --- | --- |
| `make ios-test` | DropCore 테스트 (시뮬레이터 불필요, 가장 빠른 피드백) |
| `make ios-build` | 시뮬레이터용 빌드 |
| `make ios-dev` | 시뮬레이터에서 실행 |
| `make ios-open` | Xcode로 열기 |
| `make ios-clean` | 생성물 정리 |

사전 준비: `brew install xcodegen`, Xcode 설치.

## 규칙

- **`Drop.xcodeproj`는 커밋하지 않는다.** `project.yml`이 SoT이고 `make ios-generate`가 프로젝트를 만든다 — pbxproj 머지 충돌을 없애기 위한 선택. Xcode에서 파일을 추가해도 디렉토리 구조만 맞으면 재생성 시 반영된다.
- **로컬 빌드에는 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`가 필요하다** (`xcode-select`가 CommandLineTools를 가리키고 있다). Makefile 타겟은 이미 넘긴다.
- **번들 ID는 병렬 운영 기간 동안 `com.intellieffect.drop.mobile.next`다.** Flutter 앱이 `com.intellieffect.drop.mobile`을 쓰고 있어, 같은 ID를 쓰면 한 기기에 두 앱을 동시에 설치할 수 없고 TestFlight 레코드가 겹친다. BRU-22(Flutter 제거) 시점에 `com.intellieffect.drop.mobile`로 교체한다.
- 최소 배포 타겟 **iOS 17.0** (`@Observable` 사용 조건).
