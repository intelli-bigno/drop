import SwiftUI
import UIKit

/// 확장(공유·위젯)이 쓰는 웜 페이퍼 팔레트 — 앱과 같은 색을 봐야 한다 (BRU-75).
///
/// 정본은 `design-system/drop/tokens.json`이고 Flutter 쪽은
/// `lib/theme/drop_tokens.g.dart`(생성물)가 나른다. 확장은 Flutter 코드를
/// 실을 수 없으므로 여기에서 같은 값을 손으로 든다 — 토큰이 바뀌면 이 파일도
/// 함께 바뀌어야 한다.
enum DropShellTokens {
    /// 앱 배경 (`bgPrimary`, iOS `DropTheme.Surface.page`).
    static let pageBackground = dynamicColor(light: 0xF7F6F3, dark: 0x191919)

    /// 카드·위젯 채움 (`bgCard`, iOS `DropTheme.Surface.card`).
    static let cardBackground = dynamicColor(light: 0xFFFFFF, dark: 0x202020)

    static let textPrimary = dynamicColor(light: 0x37352F, dark: 0xD4D4D4)
    static let textSecondary = dynamicColor(light: 0x6B6862, dark: 0xA8A6A1)
    static let textTertiary = dynamicColor(light: 0x9B9A97, dark: 0x8C8C8C)
    static let accent = dynamicColor(light: 0xD9730D, dark: 0xE9A23B)

    static func dynamicColor(light: UInt32, dark: UInt32) -> Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark ? uiColor(dark) : uiColor(light)
        })
    }

    private static func uiColor(_ hex: UInt32) -> UIColor {
        UIColor(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}
