import AVKit
import DropCore
import DropUI
import SwiftUI

/// `widgets/media_viewer.dart` 대응. 비공개 버킷이라 서명 URL을 받아 띄운다.
struct MediaViewer: View {
    let attachments: [Attachment]
    @State var current: Attachment

    @Environment(\.dismiss) private var dismiss
    @Environment(\.dropContainer) private var container
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
            .background(.black)
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
            ProgressView().tint(.white)
        }
    }

    private func loadURL(for attachment: Attachment) async {
        guard urls[attachment.id] == nil, let container else { return }
        do {
            urls[attachment.id] = try await container
                .makeAttachmentsRepository()
                .signedURL(for: attachment.storagePath)
        } catch {
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
                ProgressView().tint(.white)
            }
        }
    }
}
