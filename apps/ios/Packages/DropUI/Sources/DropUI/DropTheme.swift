import SwiftUI

/// 앱 전역 디자인 결정. 화면이 늘어나도 색·간격은 여기서만 정의한다.
///
/// 색의 **값**은 여기 없다 — 값의 정본은 `design-system/drop/tokens.json`이고
/// `DropTokens`(생성물)가 그것을 나른다. 이 파일이 하는 일은 그 값에 **뜻**을
/// 붙이는 것이다: "노트 행이 쉬고 있을 때의 표면", "밀어서 고정할 때의 색".
/// 화면은 `bgTertiary`가 아니라 `Surface.field`를 읽는다 — 그래야 토큰 값이
/// 바뀌어도 화면 코드가 흔들리지 않는다.
public enum DropTheme {
    public enum Spacing {
        public static let tight: CGFloat = 4
        public static let base: CGFloat = 8
        public static let comfortable: CGFloat = 16
        public static let loose: CGFloat = 24
    }

    /// 답글 계층 표현 (BRU-60).
    public enum Hierarchy {
        /// 한 단 들여쓰기 폭. 데스크톱은 24pt인데 iOS는 화면이 좁아 절반만 쓴다 —
        /// 24pt로 두면 2단에서 본문이 반으로 접힌다.
        public static let indent: CGFloat = 12
        /// 답글 왼쪽의 세로 선. 어느 노트에 딸린 줄인지 눈으로 잇는다.
        public static let railWidth: CGFloat = 2
        /// 그 선의 색. 계층을 잇는 안내선이지 정보가 아니므로 흐리게 둔다.
        public static var rail: Color { DropTokens.Colors.borderColor }
    }

    public enum Radius {
        public static let card: CGFloat = 12
        /// 목록 한 줄 행. 카드보다 조금 작게 잡아 행이 겹겹이 쌓여도 답답하지 않게.
        public static let row: CGFloat = 10
        public static let sheet: CGFloat = 20
    }

    // MARK: - 표면 (종이)

    /// **콘텐츠가 앉는 면.** 전부 불투명한 웜 페이퍼 색이다 —
    /// 여기에 유리를 쓰지 않는 이유는 뒤에 흐르는 것이 비쳐 글자가 읽히지
    /// 않기 때문이다. 유리는 기능 레이어(`Chrome`)의 재질이다 (BRU-75).
    public enum Surface {
        /// 화면 바탕. 종이 결을 살리려 순백이 아니라 살짝 따뜻한 회백이다.
        public static var page: Color { DropTokens.Colors.bgPrimary }
        /// 바탕 위에 뜨는 종이 — 노트 행·카드.
        public static var card: Color { DropTokens.Colors.bgCard }
        /// 선택된 행. 액센트를 옅게 깔아 "지금 고른 것"을 표시한다.
        public static var selected: Color { DropTokens.Colors.accentSubtle }
        /// 입력창·칩처럼 눌러 넣는 3차 표면.
        public static var field: Color { DropTokens.Colors.bgTertiary }
    }

    /// 사진·영상을 꽉 채워 보는 자리. 여기만 팔레트 밖이다 —
    /// 원본 색을 그대로 보여 주는 것이 목적이라 주변을 중립 검정으로 지운다.
    /// 종이색을 깔면 사진 색이 그 색조에 끌려간다.
    public enum Media {
        public static let background = Color.black
        public static let foreground = Color.white
    }

    /// 떠 있는 요소의 그림자. 팔레트 색이 아니라 빛의 부재라 검정 알파를 쓴다.
    public enum Elevation {
        public static let shadow = Color.black.opacity(0.12)
        public static let shadowRadius: CGFloat = 12
        public static let shadowOffsetY: CGFloat = 4
    }

    // MARK: - 밀어서 하는 동작

    /// 스와이프 버튼 색.
    ///
    /// 팔레트에 파랑·남색이 없어 예전의 `.blue` / `.indigo`를 그대로 옮길 수는
    /// 없었다. 색을 새로 만드는 대신 **뜻으로 갈랐다** — 오른쪽(노트 자체를
    /// 다루는 동작)은 액센트 계열, 왼쪽(노트에 덧붙이는 동작)은 CTA와 중립.
    public enum SwipeAction {
        /// 고정 — "지금 여기"를 가리키는 액센트.
        public static var pin: Color { DropTokens.Colors.accent }
        /// 댓글 — 누르면 새 창이 열리는 주 동작이라 CTA 색.
        public static var comment: Color { DropTokens.Colors.cta }
        /// 답글 — 같은 왼쪽 묶음의 보조 동작. 중립 슬레이트로 한 단 물린다.
        public static var reply: Color { DropTokens.Colors.priorityLow }
        public static var destructive: Color { DropTokens.Colors.danger }
    }

    /// 긴급도(`Note.priority`, 0~3) 점 색.
    /// 값은 `tokens.json`의 `color.priority.*`(shared)에서 온다 — 데스크톱·안드로이드와
    /// 같은 값이다. 두 앱이 같은 노트를 다른 색으로 보여 주면 긴급도 자체를 믿지 못하게 된다.
    public enum Priority {
        public static let dotSize: CGFloat = 5

        public static func color(for priority: Int) -> Color {
            switch priority {
            case 3: DropTokens.Colors.priorityHigh
            case 2: DropTokens.Colors.priorityMedium
            case 1: DropTokens.Colors.priorityLow
            default: DropTokens.Colors.textMuted // 0 = 중립
            }
        }
    }
}
