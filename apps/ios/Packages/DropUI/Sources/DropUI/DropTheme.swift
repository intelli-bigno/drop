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
        public static let sheet: CGFloat = 20
    }
}
