import DropCore
import SwiftUI

/// `widgets/note_card.dart` 대응.
public struct NoteCard: View {
    private static let relativeTime = RelativeTimeFormatter()

    private let note: Note
    private let isSelected: Bool
    private let isSelecting: Bool

    public init(note: Note, isSelected: Bool = false, isSelecting: Bool = false) {
        self.note = note
        self.isSelected = isSelected
        self.isSelecting = isSelecting
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
                    HStack(spacing: DropTheme.Spacing.base) {
                        ForEach(note.attachments.prefix(4)) { attachment in
                            Label(attachment.formattedSize, systemImage: icon(for: attachment.type))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .labelStyle(.titleAndIcon)
                        }
                        if note.attachments.count > 4 {
                            Text("+\(note.attachments.count - 4)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
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

    private func icon(for type: AttachmentType) -> String {
        switch type {
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
