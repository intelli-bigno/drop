import DropCore
import SwiftUI

/// 노트 카드에 붙는 첨부 미리보기 한 칸.
///
/// 이미지·영상은 실제 그림을 보여 준다. 서명 URL은 비동기로 오므로 그동안은
/// 자리를 잡아 두고, 실패하면 아이콘으로 떨어진다 — 카드 높이가 흔들리지 않게.
public struct AttachmentThumbnail: View {
    private let attachment: Attachment
    private let size: CGFloat
    private let urlProvider: (Attachment) async -> URL?

    @State private var url: URL?
    @State private var failed = false

    public init(
        attachment: Attachment,
        size: CGFloat = 72,
        urlProvider: @escaping (Attachment) async -> URL?
    ) {
        self.attachment = attachment
        self.size = size
        self.urlProvider = urlProvider
    }

    public var body: some View {
        Group {
            if attachment.isImage || attachment.isVideo, let url, !failed {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case let .success(image):
                        image.resizable().scaledToFill()
                    case .failure:
                        placeholder
                    default:
                        ProgressView().controlSize(.small)
                    }
                }
            } else {
                placeholder
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: DropTheme.Radius.card * 0.6))
        .overlay(alignment: .bottomTrailing) {
            if attachment.isVideo {
                Image(systemName: "play.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.white)
                    .shadow(radius: 2)
                    .padding(4)
            }
        }
        .task(id: attachment.id) {
            guard attachment.isImage || attachment.isVideo else { return }
            url = await urlProvider(attachment)
            failed = url == nil
        }
    }

    private var placeholder: some View {
        ZStack {
            Color.secondary.opacity(0.12)
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.body)
                    .foregroundStyle(.secondary)
                // 한 줄 행에 들어가는 작은 칸에서는 크기 문구가 잘려 나온다 —
                // 잘린 숫자 조각은 정보가 아니라 얼룩이다.
                if size >= 44, !attachment.formattedSize.isEmpty {
                    Text(attachment.formattedSize)
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    private var icon: String {
        switch attachment.type {
        case .image: "photo"
        case .audio: "waveform"
        case .video: "video"
        case .file: "doc"
        case .text: "doc.text"
        case .instagram, .youtube: "link"
        case .unknown: "questionmark.circle"
        }
    }
}
