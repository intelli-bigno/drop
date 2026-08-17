import DropCore
import DropUI
import SwiftUI

/// 한 노트의 댓글을 읽고 쓰는 자리.
///
/// 시트로 띄우는 이유: 댓글은 노트를 보다가 잠깐 덧붙이는 것이지 다른 화면으로
/// 넘어가는 일이 아니다. 목록 → 스와이프 → 댓글 → 닫기로 원래 자리에 돌아온다.
struct CommentsSheet: View {
    let note: Note
    let store: CommentsStore

    @Environment(\.dismiss) private var dismiss
    @FocusState private var isFocused: Bool
    @State private var draft = ""
    @State private var isSending = false

    private static let relativeTime = RelativeTimeFormatter()

    var body: some View {
        NavigationStack {
            list
                .navigationTitle("댓글")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("닫기") { dismiss() }
                    }
                }
                .safeAreaInset(edge: .top, spacing: 0) { noteHeader }
                .safeAreaInset(edge: .bottom) { composer }
                .task { await store.load(noteID: note.id) }
                .alert(
                    "문제가 생겼습니다",
                    isPresented: .constant(store.errorMessage != nil),
                    actions: { Button("확인") { store.dismissError() } },
                    message: { Text(store.errorMessage ?? "") }
                )
        }
        .presentationDetents([.large])
    }

    /// 어느 노트에 다는 댓글인지 늘 보이게 둔다 — 시트만 보면 맥락이 사라진다.
    private var noteHeader: some View {
        Text(note.content.isEmpty ? "빈 노트" : note.content)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .lineLimit(2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, DropTheme.Spacing.comfortable)
            .padding(.vertical, DropTheme.Spacing.base)
            .background(.bar)
    }

    /// 스크롤 컨테이너는 항상 하나, 항상 여기 있다 — 빈 상태에서도 당겨서
    /// 새로고침할 수 있어야 한다 (HomeView와 같은 불변식, PR #40).
    private var list: some View {
        List {
            let comments = store.comments(for: note.id)
            if comments.isEmpty {
                // 높이를 컨테이너에 맞추지 않는다(`containerRelativeFrame`). 위·아래
                // safeAreaInset이 붙은 List 안에서는 행 높이 → 인셋 → 컨테이너 높이가
                // 서로를 밀어 재귀 레이아웃으로 앱이 죽는다 (실측: 시뮬레이터 크래시).
                emptyState
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 96)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            } else {
                ForEach(comments) { comment in
                    row(for: comment)
                }
            }
        }
        .listStyle(.plain)
        .scrollBounceBehavior(.always, axes: .vertical)
        .refreshable { await store.load(noteID: note.id) }
    }

    private func row(for comment: NoteComment) -> some View {
        VStack(alignment: .leading, spacing: DropTheme.Spacing.tight) {
            Text(comment.body)
                .font(.subheadline)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(Self.relativeTime.string(for: comment.createdAt))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, DropTheme.Spacing.tight)
        // 댓글에는 휴지통이 없다 — 지우면 바로 사라진다. 그래서 전체 스와이프는 막는다.
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                Task { await store.delete(id: comment.id, from: note.id) }
            } label: {
                Label("삭제", systemImage: "trash")
            }
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        if store.isLoading {
            ProgressView()
                .frame(maxWidth: .infinity)
        } else {
            ContentUnavailableView("댓글이 없습니다", systemImage: "bubble.left")
        }
    }

    private var composer: some View {
        HStack(spacing: DropTheme.Spacing.base) {
            TextField("댓글 쓰기", text: $draft, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1 ... 4)
                .focused($isFocused)
                .padding(.horizontal, DropTheme.Spacing.base)
                .padding(.vertical, DropTheme.Spacing.tight)
                .background(Color.secondary.opacity(0.12), in: Capsule())

            Button {
                send()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 28))
            }
            // 보내는 중 중복 탭을 막지 않으면 같은 댓글이 두 번 올라간다.
            .disabled(isSending || trimmed.isEmpty)
        }
        .padding(.horizontal, DropTheme.Spacing.comfortable)
        .padding(.vertical, DropTheme.Spacing.base)
        .background(.bar)
    }

    private var trimmed: String {
        draft.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func send() {
        guard !isSending, !trimmed.isEmpty else { return }
        isSending = true
        let body = trimmed
        // 입력창은 즉시 비운다 — 낙관적 삽입과 같은 이유로, 보낸 것이 두 군데
        // 남아 있으면 방금 무엇을 썼는지 헷갈린다.
        draft = ""
        Task {
            await store.add(noteID: note.id, body: body)
            isSending = false
        }
    }
}
