// 이 파일은 생성물이다 — 직접 고치지 마라.
// 정본: design-system/drop/tokens.json
// 재생성: make tokens

import SwiftUI

/// 생성된 색·치수 토큰. 화면은 이 값만 쓴다 — 리터럴 색을 화면에 적으면
/// 세 앱의 색이 다시 갈라진다.
public enum DropTokens {
    public enum Colors {
        public static let bgPrimary = Color(red: 0.035, green: 0.035, blue: 0.043)
        public static let bgSecondary = Color(red: 0.063, green: 0.063, blue: 0.075)
        public static let bgCard = Color(red: 0.09, green: 0.09, blue: 0.106)
        public static let bgElevated = Color(red: 0.118, green: 0.118, blue: 0.137)
        public static let bgHover = Color(red: 0.149, green: 0.149, blue: 0.173)
        public static let accent = Color(red: 0.078, green: 0.722, blue: 0.651)
        public static let accentHover = Color(red: 0.176, green: 0.831, blue: 0.749)
        public static let accentSubtle = Color(red: 0.078, green: 0.722, blue: 0.651).opacity(0.12)
        public static let cta = Color(red: 0.918, green: 0.345, blue: 0.047)
        public static let ctaHover = Color(red: 0.976, green: 0.451, blue: 0.086)
        public static let textPrimary = Color(red: 0.98, green: 0.98, blue: 0.98)
        public static let textSecondary = Color(red: 0.651, green: 0.651, blue: 0.69)
        public static let textTertiary = Color(red: 0.475, green: 0.475, blue: 0.498)
        public static let textMuted = Color(red: 0.333, green: 0.333, blue: 0.361)
        public static let borderColor = Color(red: 1, green: 1, blue: 1).opacity(0.08)
        public static let borderSubtle = Color(red: 1, green: 1, blue: 1).opacity(0.04)
        public static let borderFocus = Color(red: 0.078, green: 0.722, blue: 0.651)
        public static let priorityLow = Color(red: 0.42, green: 0.447, blue: 0.502)
        public static let priorityMedium = Color(red: 0.961, green: 0.62, blue: 0.043)
        public static let priorityHigh = Color(red: 0.937, green: 0.267, blue: 0.267)
        public static let success = Color(red: 0.133, green: 0.773, blue: 0.369)
        public static let warning = Color(red: 0.961, green: 0.62, blue: 0.043)
        public static let danger = Color(red: 0.937, green: 0.267, blue: 0.267)
    }

    public enum Space {
        public static let x1: CGFloat = 4
        public static let x2: CGFloat = 8
        public static let x3: CGFloat = 12
        public static let x4: CGFloat = 16
        public static let x5: CGFloat = 24
        public static let x6: CGFloat = 32
        public static let x7: CGFloat = 48
        public static let x8: CGFloat = 64
    }

    public enum Radius {
        public static let sm: CGFloat = 6
        public static let md: CGFloat = 8
        public static let lg: CGFloat = 12
        public static let xl: CGFloat = 16
    }

    public enum TextSize {
        public static let xs: CGFloat = 11
        public static let sm: CGFloat = 12
        public static let base: CGFloat = 14
        public static let lg: CGFloat = 16
        public static let xl: CGFloat = 20
        public static let _2xl: CGFloat = 28
    }
}
