# DROP — Design System (Master)

> ui-ux-pro-max 생성안을 프로젝트 실정에 맞게 보정한 SoT (2026-08-11).
> 보정 사유: 생성안의 라이트 배경(#F0FDFA)은 다크 전용 앱과 모순 → 기존 OLED 다크 유지,
> 액센트만 블루 → 틸(teal) + CTA 오렌지로 전환. 페이지별 오버라이드는 `pages/`.

## 방향
- 스타일: **Dark Mode (OLED)** — 딥 블랙, 저발광, 고대비, 키보드 퍼스트
- 패턴: 단일 컬럼 피드, 밀도 7/10 (표준~조밀), 모션 3/10 (섬세한 마이크로 인터랙션만)
- 피해야 할 것: 라이트 모드 기본값, 장식성 애니메이션, 이모지 아이콘

## 토큰 (styles/index.css `:root` 와 1:1)

### 색
| 토큰 | 값 | 용도 |
|---|---|---|
| --bg-primary | #09090b | 앱 배경 |
| --bg-secondary | #101013 | 사이드바/헤더 |
| --bg-card | #17171b | 노트 카드 |
| --bg-elevated | #1e1e23 | 모달/토스트 |
| --bg-hover | #26262c | hover 표면 |
| --accent | #14b8a6 | 포커스·선택·핀 (teal) |
| --accent-hover | #2dd4bf | |
| --cta | #ea580c | 주요 행동 버튼 (orange) |
| --text-primary | #fafafa | 본문 |
| --text-secondary | #a6a6b0 | 보조 (대비 ≥4.5:1) |
| --text-tertiary | #79797f | 메타 |
| --danger | #ef4444 | 파괴적 액션 |

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
