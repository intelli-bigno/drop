import SwiftUI

/// 앱 전역 디자인 토큰. 화면이 늘어나도 색·간격은 여기서만 정의한다.
public enum DropTheme {
    public enum Spacing {
        public static let tight: CGFloat = 4
        public static let base: CGFloat = 8
        public static let comfortable: CGFloat = 16
        public static let loose: CGFloat = 24
    }

    public enum Radius {
        public static let card: CGFloat = 12
        /// 목록 한 줄 행. 카드보다 조금 작게 잡아 행이 겹겹이 쌓여도 답답하지 않게.
        public static let row: CGFloat = 10
        public static let sheet: CGFloat = 20
    }

    /// 긴급도(`Note.priority`, 0~3) 점 색. 데스크톱
    /// (`apps/desktop/src/renderer/styles/index.css`의 `--priority-*`)과 같은 값이다 —
    /// 두 앱이 같은 노트를 다른 색으로 보여 주면 긴급도 자체를 믿지 못하게 된다.
    public enum Priority {
        public static let dotSize: CGFloat = 5

        public static func color(for priority: Int) -> Color {
            switch priority {
            case 3: Color(red: 0.937, green: 0.267, blue: 0.267) // #ef4444
            case 2: Color(red: 0.961, green: 0.620, blue: 0.043) // #f59e0b
            case 1: Color(red: 0.420, green: 0.447, blue: 0.502) // #6b7280
            default: Color.secondary.opacity(0.35) // 0 = 중립
            }
        }
    }
}
