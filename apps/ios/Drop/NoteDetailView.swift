import DropCore
import DropUI
import SwiftUI

/// 노트를 **펼쳐 읽는** 자리 (BRU-77).
///
/// 목록에서 행을 누르면 여기가 열린다. 예전에는 곧장 편집기가 열렸다 —
/// 데스크톱에서 그 경로가 "펼치기만 해도 원문이 덮어써지는" 사고를 냈고(BRU-66),
/// 모바일도 같은 규칙으로 맞춘다: **열어 보는 것과 고치는 것은 다른 동작이다.**
///
/// 이 화면은 읽기 전용이다. 여기에는 저장 호출이 없다 —
/// 본문이 서버로 나가는 유일한 길은 "편집"을 눌러 여는 `NoteComposerSheet`뿐이다.
struct NoteDetailView: View {
    private static let relativeTime = RelativeTimeFormatter()

    let note: Note
    let commentCount: Int
    let comments: CommentsStore
    let attachmentURL: (Attachment) async -> URL?
    /// 편집기에서 **저장을 눌렀을 때만** 불린다. 뷰어를 열고 닫는 것만으로는 불리지 않는다.
    let onSubmitEdit: (String) async -> Void
    /// 보관·휴지통 같은 상태 변경. 본문은 건드리지 않는다.
    let onStateAction: (NoteViewerAction) async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var isEditing = false
    @State private var isShowingComments = false
    @State private var viewingAttachments: AttachmentPresentation?

    private var actions: [NoteViewerAction] { NoteViewerAction.actions(for: note) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DropTheme.Spacing.comfortable) {
                    header
                    content
                    if !note.attachments.isEmpty { attachments }
                    if !note.tags.isEmpty { tags }
                    commentsRow
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(DropTheme.Spacing.comfortable)
            }
            // 뷰어도 종이 위다 — 시스템 기본 배경을 걷어내고 웜 페이퍼를 깐다 (BRU-75).
            .scrollContentBackground(.hidden)
            .background(DropTheme.Surface.page)
            .navigationTitle(note.displayID > 0 ? "#\(note.displayID)" : "노트")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("닫기") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) { trailingActions }
            }
            .sheet(isPresented: $isEditing) {
                NoteComposerSheet(target: .existing(note), onSubmit: onSubmitEdit)
            }
            .sheet(isPresented: $isShowingComments) {
                CommentsSheet(note: note, store: comments)
            }
            .sheet(item: $viewingAttachments) { presentation in
                MediaViewer(
                    attachments: presentation.attachments,
                    urlProvider: attachmentURL,
                    current: presentation.current
                )
            }
        }
        .presentationBackground(DropTheme.Surface.page)
        .accessibilityIdentifier("노트 뷰어")
    }

    // MARK: - 조각

    /// 시각. 고친 적이 있으면 그것도 보여 준다 — 뷰어만 열었을 때 이 값이 움직이지
    /// 않는다는 것이 이 화면의 계약이다(BRU-77 완료 기준).
    private var header: some View {
        HStack(spacing: DropTheme.Spacing.base) {
            Circle()
                .fill(DropTheme.Priority.color(for: note.priority))
                .frame(width: DropTheme.Priority.dotSize, height: DropTheme.Priority.dotSize)
            if note.isPinned {
                Image(systemName: "pin.fill").font(.caption).foregroundStyle(DropTokens.Colors.accent)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(note.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(DropTokens.Colors.textSecondary)
                if note.updatedAt.timeIntervalSince(note.createdAt) > 1 {
                    Text("수정 \(Self.relativeTime.string(for: note.updatedAt))")
                        .font(.caption2)
                        .foregroundStyle(DropTokens.Colors.textTertiary)
                }
            }
            Spacer()
        }
    }

    /// 본문 전문. 줄바꿈은 그대로 둔다 — 목록에서 한 줄로 잘리던 것을 다 읽는 자리다.
    /// `Text`는 화면에 그리기만 하고 아무것도 되돌려 쓰지 않는다.
    @ViewBuilder
    private var content: some View {
        if note.content.isEmpty {
            Text("빈 노트")
                .font(.body)
                .foregroundStyle(DropTokens.Colors.textMuted)
        } else {
            Text(note.content)
                .font(.body)
                .foregroundStyle(DropTokens.Colors.textPrimary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("노트 본문")
        }
    }

    private var attachments: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 84), spacing: DropTheme.Spacing.base)],
            spacing: DropTheme.Spacing.base
        ) {
            ForEach(note.attachments) { attachment in
                AttachmentThumbnail(attachment: attachment, size: 84, urlProvider: attachmentURL)
                    .onTapGesture {
                        // 볼 수 있는 것만 뷰어로 넘긴다 — 문서는 썸네일 자리에 아이콘으로 남는다.
                        guard attachment.isImage || attachment.isVideo else { return }
                        viewingAttachments = AttachmentPresentation(
                            attachments: note.attachments.filter { $0.isImage || $0.isVideo },
                            current: attachment
                        )
                    }
            }
        }
    }

    private var tags: some View {
        HStack(spacing: DropTheme.Spacing.tight) {
            ForEach(note.tags) { tag in
                Text("#\(tag.name)")
                    .font(.caption)
                    .foregroundStyle(DropTokens.Colors.textSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(DropTheme.Surface.field, in: Capsule())
            }
        }
    }

    private var commentsRow: some View {
        Button {
            isShowingComments = true
        } label: {
            Label(
                commentCount > 0 ? "댓글 \(commentCount)개" : "댓글",
                systemImage: "bubble.left"
            )
            .font(.subheadline)
        }
        .buttonStyle(.bordered)
        // 개수가 붙어 이름이 바뀌므로(“댓글 3개”) 식별자를 따로 준다.
        .accessibilityIdentifier("댓글 열기")
    }

    /// 편집은 여기 하나뿐이다. 뷰어 어디를 눌러도 편집기가 열리지 않는다.
    @ViewBuilder
    private var trailingActions: some View {
        HStack(spacing: DropTheme.Spacing.base) {
            if actions.contains(.edit) {
                Button("편집") { isEditing = true }
                    .fontWeight(.semibold)
                    .accessibilityIdentifier("편집")
            }
            Menu {
                ForEach(actions.filter { $0 != .edit && $0 != .comments }) { action in
                    Button(role: action == .deletePermanently ? .destructive : nil) {
                        perform(action)
                    } label: {
                        Label(label(for: action), systemImage: icon(for: action))
                    }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
    }

    /// 상태를 바꿨으면 이 노트는 지금 보고 있는 목록에서 사라진다 — 뷰어도 닫는다.
    private func perform(_ action: NoteViewerAction) {
        Task {
            await onStateAction(action)
            dismiss()
        }
    }

    private func label(for action: NoteViewerAction) -> String {
        switch action {
        case .edit: "편집"
        case .comments: "댓글"
        case .archive: "보관"
        case .unarchive: "보관 해제"
        case .trash: "휴지통으로"
        case .restore: "복원"
        case .deletePermanently: "영구 삭제"
        }
    }

    private func icon(for action: NoteViewerAction) -> String {
        switch action {
        case .edit: "square.and.pencil"
        case .comments: "bubble.left"
        case .archive: "archivebox"
        case .unarchive: "tray.and.arrow.up"
        case .trash: "trash"
        case .restore: "arrow.uturn.backward"
        case .deletePermanently: "trash.slash"
        }
    }
}
