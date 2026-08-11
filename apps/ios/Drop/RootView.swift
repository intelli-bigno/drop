import DropCore
import DropUI
import SwiftUI

/// 인증 상태에 따라 갈라지는 앱의 루트.
struct RootView: View {
    @Environment(AuthStore.self) private var auth
    @Environment(\.dropContainer) private var container

    var body: some View {
        switch auth.state {
        case .undetermined:
            // 세션 확인 전에 로그인 화면을 띄우면 이미 로그인한 사용자에게
            // 로그인 화면이 한 번 깜빡인다.
            ProgressView()
        case .signedIn:
            HomePlaceholderView()
        case .signedOut, .failed, .working:
            AuthView()
        }
    }
}

/// M3(BRU-12)에서 실제 홈 화면으로 교체된다.
private struct HomePlaceholderView: View {
    @Environment(AuthStore.self) private var auth
    @Environment(\.dropContainer) private var container

    var body: some View {
        NavigationStack {
            VStack(spacing: DropTheme.Spacing.comfortable) {
                Text(auth.user?.email ?? "로그인됨")
                    .font(.headline)
                if let container {
                    Text("\(container.configuration.environment.rawValue) · \(container.configuration.supabaseURL.host() ?? "-")")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("DROP")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("로그아웃") { Task { await auth.signOut() } }
                }
            }
        }
    }
}
