import DropCore
import SwiftUI

/// 목록 한 줄 행. 긴급도 점 · 본문 · 태그 · 상대시간이 한 줄에 들어간다.
///
/// 본문을 8줄까지 펼치던 카드에서 한 줄로 줄인 것은 한 화면에 들어오는 노트 수를
/// 늘리기 위해서다(BRU-49). 내용을 다 읽는 자리는 목록이 아니라 컴포저다.
public struct NoteCard: View {
    private static let relativeTime = RelativeTimeFormatter()

    /// 한 줄에 붙일 수 있는 첨부·태그 수의 상한. 넘으면 +N으로 접는다 —
    /// 첨부가 많은 노트 하나 때문에 줄이 밀려 다른 정보가 잘리면 안 된다.
    private static let inlineAttachmentLimit = 3
    private static let inlineTagLimit = 2

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
        HStack(spacing: DropTheme.Spacing.base) {
            if isSelecting {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                    .font(.subheadline)
            }

            Circle()
                .fill(DropTheme.Priority.color(for: note.priority))
                .frame(width: DropTheme.Priority.dotSize, height: DropTheme.Priority.dotSize)

            if note.isPinned {
                Image(systemName: "pin.fill")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }

            if note.isLocked {
                Image(systemName: "lock.fill")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            contentText
                // 남는 폭은 본문이 가져간다. 태그·시간은 제 크기만 쓰고 물러난다.
                .layoutPriority(1)

            Spacer(minLength: DropTheme.Spacing.tight)

            attachments

            tags

            Text(Self.relativeTime.string(for: note.createdAt))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .fixedSize()
        }
        .padding(.horizontal, DropTheme.Spacing.comfortable * 0.75)
        .padding(.vertical, DropTheme.Spacing.base)
        .background(
            Color.secondary.opacity(isSelected ? 0.16 : 0.06),
            in: RoundedRectangle(cornerRadius: DropTheme.Radius.row)
        )
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var contentText: some View {
        if note.content.isEmpty {
            Text("빈 노트")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        } else {
            Text(note.content)
                .font(.subheadline)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var attachments: some View {
        if !note.attachments.isEmpty {
            HStack(spacing: 2) {
                ForEach(note.attachments.prefix(Self.inlineAttachmentLimit)) { attachment in
                    AttachmentThumbnail(attachment: attachment, size: 22, urlProvider: attachmentURL)
                        // 선택 모드에서는 탭이 선택을 바꿔야 한다 —
                        // 여기서 뷰어가 열리면 선택이 어긋난다.
                        .onTapGesture {
                            guard !isSelecting else { return }
                            onOpenAttachment(attachment)
                        }
                }
                if note.attachments.count > Self.inlineAttachmentLimit {
                    Text("+\(note.attachments.count - Self.inlineAttachmentLimit)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .fixedSize()
        }
    }

    @ViewBuilder
    private var tags: some View {
        if !note.tags.isEmpty {
            HStack(spacing: DropTheme.Spacing.tight) {
                ForEach(note.tags.prefix(Self.inlineTagLimit)) { tag in
                    Text("#\(tag.name)")
                        .font(.caption2)
                        .lineLimit(1)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(Color.secondary.opacity(0.12), in: Capsule())
                }
                if note.tags.count > Self.inlineTagLimit {
                    Text("+\(note.tags.count - Self.inlineTagLimit)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .fixedSize()
        }
    }
}
