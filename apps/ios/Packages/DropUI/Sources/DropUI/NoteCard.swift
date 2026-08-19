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
                    .fill(Color.secondary.opacity(0.25))
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

            // 부모가 이 목록에 없어 최상위로 올라온 답글. 표시가 없으면 독립 노트로 읽힌다.
            if isOrphanedReply {
                Image(systemName: "arrow.turn.up.left")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
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

    /// 한 줄 행에 태울 글자.
    ///
    /// 원문을 그대로 태우면 `## 제목`이 `##`째로 보인다 — 한 줄만 보이는 자리에서는
    /// 기호가 읽을 수 있는 정보의 절반을 먹는다. 그래서 문법을 걷어낸 평문을 쓴다 (BRU-37).
    ///
    /// 앞부분만 잘라 넘기는 것은 목록 성능 때문이다. 어차피 한 줄만 보이는데
    /// 긴 노트를 통째로 파싱하면 스크롤할 때마다 그 값을 치른다.
    private var summary: String {
        MarkdownParser().parse(String(note.content.prefix(Self.previewCharacterLimit))).singleLineSummary
    }

    /// 한 줄 미리보기를 만들 때 읽는 원문 길이의 상한.
    private static let previewCharacterLimit = 300

    @ViewBuilder
    private var contentText: some View {
        let summary = summary
        if summary.isEmpty {
            Text("빈 노트")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        } else {
            Text(summary)
                .font(.subheadline)
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
            .foregroundStyle(.secondary)
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
