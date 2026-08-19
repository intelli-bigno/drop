import AVKit
import DropCore
import DropUI
import SwiftUI

/// `widgets/media_viewer.dart` 대응. 비공개 버킷이라 서명 URL을 받아 띄운다.
struct MediaViewer: View {
    let attachments: [Attachment]
    /// 목록 화면이 쓰던 것과 같은 제공자를 받는다 — 썸네일로 이미 받아 둔 서명 URL을
    /// 재사용해 뷰어를 열 때 다시 발급받지 않는다.
    let urlProvider: (Attachment) async -> URL?
    @State var current: Attachment

    @Environment(\.dismiss) private var dismiss
    @State private var urls: [String: URL] = [:]
    @State private var failed: Set<String> = []

    var body: some View {
        NavigationStack {
            TabView(selection: $current) {
                ForEach(attachments) { attachment in
                    page(for: attachment)
                        .tag(attachment)
                }
            }
            .tabViewStyle(.page)
            // 여기만 팔레트 밖이다 — 사진 원본 색을 그대로 보여 주는 것이 목적이라
            // 주변을 중립 검정으로 지운다. 종이색을 깔면 사진이 그 색조에 끌려간다.
            .background(DropTheme.Media.background)
            .navigationTitle(current.filename ?? "첨부")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("닫기") { dismiss() }
                }
            }
        }
        .task(id: current.id) { await loadURL(for: current) }
    }

    @ViewBuilder
    private func page(for attachment: Attachment) -> some View {
        if failed.contains(attachment.id) {
            ContentUnavailableView("불러오지 못했습니다", systemImage: "exclamationmark.triangle")
        } else if let url = urls[attachment.id] {
            switch attachment.type {
            case .video:
                VideoPlayer(player: AVPlayer(url: url))
            default:
                ZoomableImage(url: url)
            }
        } else {
            ProgressView().tint(DropTheme.Media.foreground)
        }
    }

    private func loadURL(for attachment: Attachment) async {
        guard urls[attachment.id] == nil else { return }
        if let url = await urlProvider(attachment) {
            urls[attachment.id] = url
        } else {
            failed.insert(attachment.id)
        }
    }
}

/// 핀치 줌 + 더블탭 확대. 확대 상태에서 페이지가 넘어가지 않도록 배율이 1일 때만 스와이프를 넘긴다.
private struct ZoomableImage: View {
    let url: URL

    @State private var scale: CGFloat = 1
    @GestureState private var pinch: CGFloat = 1

    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case let .success(image):
                image
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(scale * pinch)
                    .gesture(
                        MagnificationGesture()
                            .updating($pinch) { value, state, _ in state = value }
                            .onEnded { value in scale = min(max(scale * value, 1), 6) }
                    )
                    .onTapGesture(count: 2) {
                        withAnimation(.snappy) { scale = scale > 1 ? 1 : 2.5 }
                    }
            case .failure:
                ContentUnavailableView("불러오지 못했습니다", systemImage: "photo")
            default:
                ProgressView().tint(DropTheme.Media.foreground)
            }
        }
    }
}
