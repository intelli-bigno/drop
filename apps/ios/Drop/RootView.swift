import DropCore
import DropUI
import SwiftUI

/// 스캐폴드 단계의 임시 루트. BRU-8(로그인)에서 인증 상태에 따른 분기로 교체된다.
struct RootView: View {
    @Environment(\.dropContainer) private var container

    var body: some View {
        VStack(spacing: DropTheme.Spacing.comfortable) {
            Text("DROP")
                .font(.largeTitle.bold())
            if let container {
                Text("\(container.configuration.environment.rawValue) · \(container.configuration.supabaseURL.host() ?? "-")")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(DropTheme.Spacing.loose)
    }
}

#Preview {
    RootView()
}
