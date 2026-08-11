import DropCore
import DropUI
import SwiftUI

/// 인증 상태에 따라 갈라지는 앱의 루트.
struct RootView: View {
    @Environment(AuthStore.self) private var auth
    @Environment(\.dropContainer) private var container

    var body: some View {
        #if DEBUG
        if PreviewLaunch.isActive {
            HomeView(
                repository: PreviewLaunch.makeRepository(),
                previewAttachmentURL: PreviewLaunch.attachmentURL
            )
        } else {
            authenticatedBody
        }
        #else
        authenticatedBody
        #endif
    }

    @ViewBuilder
    private var authenticatedBody: some View {
        switch auth.state {
        case .undetermined:
            // 세션 확인 전에 로그인 화면을 띄우면 이미 로그인한 사용자에게
            // 로그인 화면이 한 번 깜빡인다.
            ProgressView()
        case .signedIn:
            if let container {
                // 로그인한 사용자가 바뀌면 목록 상태를 처음부터 다시 만든다.
                HomeView(repository: container.makeNotesRepository())
                    .id(auth.user?.id)
            }
        case .signedOut, .failed, .working:
            AuthView()
        }
    }
}
