// 이 파일은 생성물이다 — 직접 고치지 마라.
// 정본: design-system/drop/tokens.json
// 재생성: make tokens

import SwiftUI
import UIKit

/// 생성된 색·치수 토큰. 화면은 이 값만 쓴다 — 리터럴 색을 화면에 적으면
/// 세 앱의 색이 다시 갈라진다.
public enum DropTokens {
    public enum Colors {
        public static let bgPrimary = DropTokens.adaptive(light: Color(red: 0.969, green: 0.965, blue: 0.953), dark: Color(red: 0.098, green: 0.098, blue: 0.098))
        public static let bgSecondary = DropTokens.adaptive(light: Color(red: 0.945, green: 0.937, blue: 0.918), dark: Color(red: 0.11, green: 0.11, blue: 0.11))
        public static let bgCard = DropTokens.adaptive(light: Color(red: 1, green: 1, blue: 1), dark: Color(red: 0.125, green: 0.125, blue: 0.125))
        public static let bgElevated = DropTokens.adaptive(light: Color(red: 1, green: 1, blue: 1), dark: Color(red: 0.149, green: 0.149, blue: 0.149))
        public static let bgTertiary = DropTokens.adaptive(light: Color(red: 0.929, green: 0.918, blue: 0.89), dark: Color(red: 0.165, green: 0.165, blue: 0.165))
        public static let bgHover = DropTokens.adaptive(light: Color(red: 0.929, green: 0.918, blue: 0.89), dark: Color(red: 0.18, green: 0.18, blue: 0.18))
        public static let accent = DropTokens.adaptive(light: Color(red: 0.851, green: 0.451, blue: 0.051), dark: Color(red: 0.914, green: 0.635, blue: 0.231))
        public static let accentHover = DropTokens.adaptive(light: Color(red: 0.706, green: 0.325, blue: 0.035), dark: Color(red: 0.949, green: 0.706, blue: 0.353))
        public static let accentSubtle = DropTokens.adaptive(light: Color(red: 0.851, green: 0.451, blue: 0.051).opacity(0.12), dark: Color(red: 0.914, green: 0.635, blue: 0.231).opacity(0.14))
        public static let cta = DropTokens.adaptive(light: Color(red: 0.816, green: 0.275, blue: 0.051), dark: Color(red: 0.976, green: 0.451, blue: 0.086))
        public static let ctaHover = DropTokens.adaptive(light: Color(red: 0.604, green: 0.204, blue: 0.071), dark: Color(red: 0.984, green: 0.573, blue: 0.235))
        public static let textOnAccent = DropTokens.adaptive(light: Color(red: 0, green: 0, blue: 0), dark: Color(red: 0, green: 0, blue: 0))
        public static let textPrimary = DropTokens.adaptive(light: Color(red: 0.216, green: 0.208, blue: 0.184), dark: Color(red: 0.831, green: 0.831, blue: 0.831))
        public static let textSecondary = DropTokens.adaptive(light: Color(red: 0.42, green: 0.408, blue: 0.384), dark: Color(red: 0.659, green: 0.651, blue: 0.631))
        public static let textTertiary = DropTokens.adaptive(light: Color(red: 0.553, green: 0.549, blue: 0.537), dark: Color(red: 0.549, green: 0.549, blue: 0.549))
        public static let textMuted = DropTokens.adaptive(light: Color(red: 0.706, green: 0.698, blue: 0.675), dark: Color(red: 0.42, green: 0.416, blue: 0.4))
        public static let borderColor = DropTokens.adaptive(light: Color(red: 0.216, green: 0.208, blue: 0.184).opacity(0.12), dark: Color(red: 1, green: 1, blue: 1).opacity(0.09))
        public static let borderSubtle = DropTokens.adaptive(light: Color(red: 0.216, green: 0.208, blue: 0.184).opacity(0.06), dark: Color(red: 1, green: 1, blue: 1).opacity(0.05))
        public static let borderFocus = DropTokens.adaptive(light: Color(red: 0.851, green: 0.451, blue: 0.051), dark: Color(red: 0.914, green: 0.635, blue: 0.231))
        public static let priorityLow = DropTokens.adaptive(light: Color(red: 0.42, green: 0.447, blue: 0.502), dark: Color(red: 0.42, green: 0.447, blue: 0.502))
        public static let priorityMedium = DropTokens.adaptive(light: Color(red: 0.961, green: 0.62, blue: 0.043), dark: Color(red: 0.961, green: 0.62, blue: 0.043))
        public static let priorityHigh = DropTokens.adaptive(light: Color(red: 0.937, green: 0.267, blue: 0.267), dark: Color(red: 0.937, green: 0.267, blue: 0.267))
        public static let success = DropTokens.adaptive(light: Color(red: 0.133, green: 0.773, blue: 0.369), dark: Color(red: 0.133, green: 0.773, blue: 0.369))
        public static let warning = DropTokens.adaptive(light: Color(red: 0.961, green: 0.62, blue: 0.043), dark: Color(red: 0.961, green: 0.62, blue: 0.043))
        public static let danger = DropTokens.adaptive(light: Color(red: 0.855, green: 0.137, blue: 0.137), dark: Color(red: 0.937, green: 0.267, blue: 0.267))
        public static let dangerHover = DropTokens.adaptive(light: Color(red: 0.725, green: 0.11, blue: 0.11), dark: Color(red: 0.973, green: 0.443, blue: 0.443))
        public static let dangerSubtle = DropTokens.adaptive(light: Color(red: 0.855, green: 0.137, blue: 0.137).opacity(0.1), dark: Color(red: 0.937, green: 0.267, blue: 0.267).opacity(0.14))
        public static let overlay = DropTokens.adaptive(light: Color(red: 0.216, green: 0.208, blue: 0.184).opacity(0.32), dark: Color(red: 0, green: 0, blue: 0).opacity(0.6))
        public static let overlayStrong = DropTokens.adaptive(light: Color(red: 0, green: 0, blue: 0).opacity(0.92), dark: Color(red: 0, green: 0, blue: 0).opacity(0.92))
        public static let overlayControl = DropTokens.adaptive(light: Color(red: 1, green: 1, blue: 1).opacity(0.12), dark: Color(red: 1, green: 1, blue: 1).opacity(0.12))
        public static let overlayControlHover = DropTokens.adaptive(light: Color(red: 1, green: 1, blue: 1).opacity(0.22), dark: Color(red: 1, green: 1, blue: 1).opacity(0.22))
        public static let overlayScrim = DropTokens.adaptive(light: Color(red: 0, green: 0, blue: 0).opacity(0.55), dark: Color(red: 0, green: 0, blue: 0).opacity(0.55))
        public static let textOnOverlay = DropTokens.adaptive(light: Color(red: 1, green: 1, blue: 1), dark: Color(red: 1, green: 1, blue: 1))
        public static let textOnDanger = DropTokens.adaptive(light: Color(red: 1, green: 1, blue: 1), dark: Color(red: 1, green: 1, blue: 1))
        public static let brandInstagram = DropTokens.adaptive(light: Color(red: 0.882, green: 0.188, blue: 0.424), dark: Color(red: 0.882, green: 0.188, blue: 0.424))
        public static let brandYoutube = DropTokens.adaptive(light: Color(red: 1, green: 0, blue: 0), dark: Color(red: 1, green: 0, blue: 0))
    }

    /// 시스템 외양에 따라 스스로 바뀌는 색.
    ///
    /// SwiftUI `Color`는 두 값을 품지 못해서 UIKit의 동적 색으로 만든다 —
    /// 이렇게 해야 다크 모드 전환이 뷰 코드 없이 즉시 반영된다.
    fileprivate static func adaptive(light: Color, dark: Color) -> Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
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
        public static let _3xl: CGFloat = 44
    }
}
