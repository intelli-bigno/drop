# Braindump 아이콘

**산출물 생성: `apps/desktop/build/logo/generate.sh`** (macOS 전용, 추가 설치 불필요 — `sips`/`iconutil` 사용)

## 소스

| 파일 | 용도 |
|---|---|
| `a-solid-drop.svg` | **채택안.** Dock 아이콘 원본 (틸 그라디언트 + 흰 물방울) |
| `tray-drop-template.svg` | 메뉴바 트레이 원본. macOS 템플릿 이미지 규칙상 단색(검정)+알파만 — 색은 시스템이 라이트/다크에 맞춰 반전한다 |
| `b-oled-outline.svg` `c-capture-line.svg` `d-negative-drop.svg` | 미채택 후보. 방향 재검토 시 출발점으로 보존 |

## 산출물 (`generate.sh`가 `apps/desktop/build/`에 생성)

- `icon.icns` — electron-builder `build.mac.icon`이 참조 (Dock·앱 스위처·DMG)
- `icon.png` — 1024px 원본, icns 생성 중간 산출물 겸 범용 용도
- `trayIconTemplate.png` / `@2x.png` — 메뉴바 (16 / 32px)

AuthScreen의 로고는 `a-solid-drop.svg`를 인라인 SVG로 옮겨 둔 것이라, 마크를 바꾸면 `AuthScreen.tsx`도 같이 고쳐야 한다.

## 색

디자인 시스템 토큰만 사용 (`design-system/drop/MASTER.md`): 틸 `#14b8a6` / `#2dd4bf` / `#0d9488`, OLED 블랙 `#09090b`, 텍스트 `#fafafa`.
