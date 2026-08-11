import DropCore
import SwiftUI

/// `widgets/note_card.dart` 대응.
public struct NoteCard: View {
    private static let relativeTime = RelativeTimeFormatter()

    private let note: Note
    private let isSelected: Bool
    private let isSelecting: Bool
    private let attachmentURL: (Attachment) async -> URL?
    private let onOpenAttachment: (Attachment) -> Void

    public init(
        note: Note,
        isSelected: Bool = false,
        isSelecting: Bool = false,
        attachmentURL: @escaping (Attachment) async -> URL? = { _ in nil },
        onOpenAttachment: @escaping (Attachment) -> Void = { _ in }
    ) {
        self.note = note
        self.isSelected = isSelected
        self.isSelecting = isSelecting
        self.attachmentURL = attachmentURL
        self.onOpenAttachment = onOpenAttachment
    }

    public var body: some View {
        HStack(alignment: .top, spacing: DropTheme.Spacing.comfortable) {
            if isSelecting {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                    .font(.title3)
                    .padding(.top, 2)
            }

            VStack(alignment: .leading, spacing: DropTheme.Spacing.base) {
                HStack(spacing: DropTheme.Spacing.tight) {
                    if note.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                    Text(Self.relativeTime.string(for: note.createdAt))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    if note.isLocked {
                        Image(systemName: "lock.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                if note.content.isEmpty {
                    Text("빈 노트")
                        .font(.body)
                        .foregroundStyle(.tertiary)
                } else {
                    Text(note.content)
                        .font(.body)
                        .lineLimit(8)
                        .multilineTextAlignment(.leading)
                }

                if !note.attachments.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: DropTheme.Spacing.base) {
                            ForEach(note.attachments) { attachment in
                                AttachmentThumbnail(attachment: attachment, urlProvider: attachmentURL)
                                    // 선택 모드에서는 탭이 선택을 바꿔야 한다 —
                                    // 여기서 뷰어가 열리면 선택이 어긋난다.
                                    .onTapGesture {
                                        guard !isSelecting else { return }
                                        onOpenAttachment(attachment)
                                    }
                            }
                        }
                    }
                    // 카드 밖으로 나가는 가로 스크롤이 세로 스크롤을 방해하지 않게.
                    .scrollClipDisabled(false)
                }

                if !note.tags.isEmpty {
                    HStack(spacing: DropTheme.Spacing.tight) {
                        ForEach(note.tags) { tag in
                            Text("#\(tag.name)")
                                .font(.caption2)
                                .padding(.horizontal, DropTheme.Spacing.base)
                                .padding(.vertical, 2)
                                .background(Color.secondary.opacity(0.12), in: Capsule())
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(DropTheme.Spacing.comfortable)
        .background(Color.secondary.opacity(isSelected ? 0.16 : 0.06), in: RoundedRectangle(cornerRadius: DropTheme.Radius.card))
        .contentShape(Rectangle())
    }

}
