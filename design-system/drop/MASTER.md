# DROP — Design System (Master)

> **기계가 읽는 정본은 `tokens.json`이다** (BRU-73). 이 문서는 사람이 읽는 설명이고,
> 색값 표는 참고용이다 — 실제 값은 JSON을 보고, 바꿀 때도 JSON만 고친 뒤 `make tokens`를 돌린다.
>
> 2026-08-18 (BRU-72): 팔레트를 **웜 페이퍼 + 앰버**로 교체하고 **라이트·다크 두 모드**를 갖췄다.
> 그전에는 OLED 다크 + teal 단일 모드였다.

## 방향
- 스타일: **웜 페이퍼** — 종이에 가까운 웜 뉴트럴 바탕, 액센트는 앰버 하나. 라이트가 본체, 다크는 밤용.
- 패턴: 단일 컬럼 피드, 밀도 7/10 (표준~조밀), 모션 3/10 (섬세한 마이크로 인터랙션만)
- 피해야 할 것: 장식성 애니메이션, 이모지 아이콘, **화면에 색 리터럴 적기**(토큰만 쓴다)
- 플랫폼 재질은 각자 따른다 — iOS는 Liquid Glass(기능 레이어에만), Android는 M3 표면. 같은 것은 색·간격·타이포다.

## 토큰

값의 정본은 `design-system/drop/tokens.json`이다. 생성물:

| 대상 | 파일 |
| --- | --- |
| 데스크톱 | `apps/desktop/src/renderer/styles/tokens.css` |
| iOS | `apps/ios/Packages/DropUI/Sources/DropUI/DropTokens.swift` |
| Android | `apps/android/app/src/main/kotlin/.../DropTokens.kt` |

### 색 — 라이트 / 다크
| 토큰 | Light | Dark | 용도 |
|---|---|---|---|
| --bg-primary | #f7f6f3 | #191919 | 앱 배경 |
| --bg-secondary | #f1efea | #1c1c1c | 사이드바/헤더 |
| --bg-card | #ffffff | #202020 | 노트 카드 |
| --bg-elevated | #ffffff | #262626 | 모달/토스트 |
| --bg-tertiary | #edeae3 | #2a2a2a | 입력 등 3차 표면 |
| --bg-hover | #edeae3 | #2e2e2e | hover 표면 |
| --accent | #d9730d | #e9a23b | 포커스·선택·핀 |
| --cta | #c2410c | #f97316 | 주요 행동 버튼 |
| --text-primary | #37352f | #d4d4d4 | 본문 |
| --text-secondary | #6b6862 | #a8a6a1 | 보조 (≥4.5:1) |
| --text-tertiary | #9b9a97 | #8c8c8c | 메타 — **본문 금지** |
| --text-on-accent | #1a1a1a | #1a1a1a | 액센트·CTA 위 글자 |
| --danger | #dc2626 | #ef4444 | 파괴적 액션 |

**액센트 위에는 어두운 글자를 쓴다.** 두 모드 모두 액센트가 밝은 주황 계열이라 흰 글자는 대비가 3:1 아래로 떨어진다(라이트 3.3:1, 다크 2.2:1 — 실측).

### 간격 (4px 베이스)
--space-1..8 = 4 / 8 / 12 / 16 / 24 / 32 / 48 / 64

### 타이포
- 폰트: Inter(현행 유지 — 교체 시 페이지 오버라이드로), JetBrains Mono(코드)
- 스케일 --text-xs..2xl = 11 / 12 / 14 / 16 / 20 / 28, 본문 14px·line-height 1.5
- 12px 미만 본문 금지 (메타 라벨만 11px 허용)

## 규칙
1. 아이콘은 SVG(lucide 스타일, stroke=currentColor)만 — 이모지 금지. 아이콘 단독 버튼은 `aria-label` 필수.
2. 컴포넌트에 raw hex 금지 — 토큰만. 신규 스타일은 index.css(전역) 또는 컴포넌트 전용 css 파일.
3. 인터랙션: hover 전환 150ms, `:focus-visible` 2px accent 아웃라인, `prefers-reduced-motion` 존중, 클릭 요소 cursor:pointer.
4. 파괴적 액션: 소프트 삭제=낙관적+실행취소 토스트, 영구 삭제=ConfirmDialog(danger).
5. 빈/로딩/오류 상태 필수: 빈 상태는 다음 행동 힌트 포함, 로딩은 스켈레톤(레이아웃 시프트 0), 오류는 토스트+재시도.
