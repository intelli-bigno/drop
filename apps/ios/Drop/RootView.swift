import DropCore
import DropUI
import SwiftUI

/// 인증 상태에 따라 갈라지는 앱의 루트.
struct RootView: View {
    @Environment(AuthStore.self) private var auth
    @Environment(\.dropContainer) private var container

    var body: some View {
        #if DEBUG
        if PreviewLaunch.usesSeededLocalSession, let container {
            SeededLocalSessionGate(container: container)
        } else if PreviewLaunch.isActive {
            HomeView(
                repository: PreviewLaunch.makeRepository(),
                commentsRepository: PreviewLaunch.makeCommentsRepository(),
                previewAttachmentURL: PreviewLaunch.attachmentURL
            )
        } else {
            authenticatedBody
        }
        #else
        authenticatedBody
        #endif
    }

    #if DEBUG
    /// 로컬 시드 사용자로 붙은 뒤에야 목록을 띄운다 — 세션 없이 먼저 부르면
    /// RLS에 막혀 빈 목록이 뜨고, 그 빈 화면을 "노트가 없다"로 잘못 읽게 된다.
    private struct SeededLocalSessionGate: View {
        let container: DropEnvironmentContainer

        @State private var isReady = false
        @State private var failure: String?

        var body: some View {
            Group {
                if isReady {
                    HomeView(
                        repository: container.makeNotesRepository(),
                        commentsRepository: container.makeCommentsRepository()
                    )
                } else if let failure {
                    ContentUnavailableView(
                        "로컬 세션을 열지 못했습니다",
                        systemImage: "bolt.horizontal.circle",
                        description: Text(failure)
                    )
                } else {
                    ProgressView()
                }
            }
            .task {
                do {
                    try await container.signInWithSeededLocalUser()
                    isReady = true
                } catch {
                    failure = "\(error)"
                }
            }
        }
    }
    #endif

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
                HomeView(
                    repository: container.makeNotesRepository(),
                    commentsRepository: container.makeCommentsRepository()
                )
                .id(auth.user?.id)
            }
        case .signedOut, .failed, .working:
            AuthView()
        }
    }
}
