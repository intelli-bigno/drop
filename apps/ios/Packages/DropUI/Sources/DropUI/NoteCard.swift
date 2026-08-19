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
    private let commentCount: Int
    /// 들여쓰기 단수. 0이면 최상위 노트다 (BRU-60).
    private let depth: Int
    /// 부모가 이 목록에 없어 최상위로 올라온 답글. 독립 노트처럼 보이면 맥락이 사라진다.
    private let isOrphanedReply: Bool
    private let attachmentURL: (Attachment) async -> URL?
    private let onOpenAttachment: (Attachment) -> Void

    public init(
        note: Note,
        isSelected: Bool = false,
        isSelecting: Bool = false,
        commentCount: Int = 0,
        depth: Int = 0,
        isOrphanedReply: Bool = false,
        attachmentURL: @escaping (Attachment) async -> URL? = { _ in nil },
        onOpenAttachment: @escaping (Attachment) -> Void = { _ in }
    ) {
        self.note = note
        self.isSelected = isSelected
        self.isSelecting = isSelecting
        self.commentCount = commentCount
        self.depth = depth
        self.isOrphanedReply = isOrphanedReply
        self.attachmentURL = attachmentURL
        self.onOpenAttachment = onOpenAttachment
    }

    public init(row: NoteRow, isSelected: Bool = false, isSelecting: Bool = false, commentCount: Int = 0,
                attachmentURL: @escaping (Attachment) async -> URL? = { _ in nil },
                onOpenAttachment: @escaping (Attachment) -> Void = { _ in }) {
        self.init(
            note: row.note,
            isSelected: isSelected,
            isSelecting: isSelecting,
            commentCount: commentCount,
            depth: row.depth,
            isOrphanedReply: row.isOrphanedReply,
            attachmentURL: attachmentURL,
            onOpenAttachment: onOpenAttachment
        )
    }

    public var body: some View {
        HStack(spacing: 0) {
            // 답글 왼쪽의 세로 선. 들여쓴 만큼 자리를 내주고, 그 끝에 선을 세운다.
            if depth > 0 {
                Color.clear
                    .frame(width: DropTheme.Hierarchy.indent * CGFloat(depth))
                Capsule()
                    .fill(DropTheme.Hierarchy.rail)
                    .frame(width: DropTheme.Hierarchy.railWidth)
                    .padding(.trailing, DropTheme.Spacing.base)
            }

            row
        }
    }

    private var row: some View {
        HStack(spacing: DropTheme.Spacing.base) {
            if isSelecting {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? DropTokens.Colors.accent : DropTokens.Colors.textTertiary)
                    .font(.subheadline)
            }

            Circle()
                .fill(DropTheme.Priority.color(for: note.priority))
                .frame(width: DropTheme.Priority.dotSize, height: DropTheme.Priority.dotSize)

            if note.isPinned {
                Image(systemName: "pin.fill")
                    .font(.caption2)
                    .foregroundStyle(DropTokens.Colors.accent)
            }

            if note.isLocked {
                Image(systemName: "lock.fill")
                    .font(.caption2)
                    .foregroundStyle(DropTokens.Colors.textSecondary)
            }

            // 부모가 이 목록에 없어 최상위로 올라온 답글. 표시가 없으면 독립 노트로 읽힌다.
            if isOrphanedReply {
                Image(systemName: "arrow.turn.up.left")
                    .font(.caption2)
                    .foregroundStyle(DropTokens.Colors.textSecondary)
                    .accessibilityLabel("답글")
            }

            contentText
                // 남는 폭은 본문이 가져간다. 태그·시간은 제 크기만 쓰고 물러난다.
                .layoutPriority(1)

            Spacer(minLength: DropTheme.Spacing.tight)

            comments

            attachments

            tags

            Text(Self.relativeTime.string(for: note.createdAt))
                .font(.caption2)
                .foregroundStyle(DropTokens.Colors.textTertiary)
                .lineLimit(1)
                .fixedSize()
        }
        .padding(.horizontal, DropTheme.Spacing.comfortable * 0.75)
        .padding(.vertical, DropTheme.Spacing.base)
        // **종이다. 유리가 아니다.** 목록 행은 콘텐츠 레이어라 뒤가 비치면
        // 본문이 읽히지 않는다 — 유리는 툴바·FAB·시트에만 쓴다 (BRU-75).
        .background(
            isSelected ? DropTheme.Surface.selected : DropTheme.Surface.card,
            in: RoundedRectangle(cornerRadius: DropTheme.Radius.row)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DropTheme.Radius.row)
                .stroke(isSelected ? DropTokens.Colors.borderFocus : DropTokens.Colors.borderSubtle)
        )
        .contentShape(Rectangle())
    }

    /// 한 줄 행에 태울 글자. 만드는 일도 기억하는 일도 `MarkdownSummaryCache`가 한다 —
    /// 여기서 파싱하면 스크롤 한 번에 여러 번 도는 `body`가 곧 파싱이 된다 (BRU-37).
    @MainActor
    private var summary: String {
        MarkdownSummaryCache.summary(for: note.content)
    }

    @ViewBuilder
    private var contentText: some View {
        let summary = summary
        if summary.isEmpty {
            Text("빈 노트")
                .font(.subheadline)
                .foregroundStyle(DropTokens.Colors.textMuted)
                .lineLimit(1)
        } else {
            Text(summary)
                .font(.subheadline)
                .foregroundStyle(DropTokens.Colors.textPrimary)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// 댓글 개수 표식. 첨부 개수 표식과 같은 자리·같은 크기로 붙는다 —
    /// 한 줄 규칙(BRU-49)을 지키려면 새 줄이 아니라 이 줄에 들어가야 한다.
    /// **0이면 아예 그리지 않는다.** 대부분의 노트에는 댓글이 없고,
    /// 빈 말풍선이 줄마다 붙으면 있는 노트가 눈에 띄지 않는다.
    @ViewBuilder
    private var comments: some View {
        if commentCount > 0 {
            HStack(spacing: 2) {
                Image(systemName: "bubble.left")
                Text("\(commentCount)")
            }
            .font(.caption2)
            .foregroundStyle(DropTokens.Colors.textSecondary)
            .fixedSize()
            .accessibilityLabel("댓글 \(commentCount)개")
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
                        .foregroundStyle(DropTokens.Colors.textSecondary)
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
                        .foregroundStyle(DropTokens.Colors.textSecondary)
                        .background(DropTheme.Surface.field, in: Capsule())
                }
                if note.tags.count > Self.inlineTagLimit {
                    Text("+\(note.tags.count - Self.inlineTagLimit)")
                        .font(.caption2)
                        .foregroundStyle(DropTokens.Colors.textSecondary)
                }
            }
            .fixedSize()
        }
    }
}
