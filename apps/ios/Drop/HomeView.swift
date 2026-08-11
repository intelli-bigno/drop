import DropCore
import DropUI
import SwiftUI

/// `screens/home_screen.dart` 대응. 앱 사용 시간의 대부분이 여기다.
struct HomeView: View {
    @Environment(AuthStore.self) private var auth
    @State private var notes: NotesStore
    @State private var composer: ComposerTarget?

    init(repository: any NotesRepository) {
        _notes = State(wrappedValue: NotesStore(repository: repository))
    }

    var body: some View {
        @Bindable var notes = notes

        NavigationStack {
            content
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .searchable(text: $notes.searchText, prompt: "노트 검색")
                .toolbar { toolbar }
                .safeAreaInset(edge: .top, spacing: 0) { filters }
                .safeAreaInset(edge: .bottom) { bottomBar }
                .refreshable { await notes.load() }
                .task { await notes.load() }
                .sheet(item: $composer) { target in
                    NoteComposerSheet(target: target) { content in
                        switch target {
                        case .new:
                            await notes.create(content: content)
                        case let .existing(note):
                            await notes.update(id: note.id, content: content)
                        }
                    }
                }
                .alert(
                    "문제가 생겼습니다",
                    isPresented: .constant(notes.errorMessage != nil),
                    actions: { Button("확인") { notes.dismissError() } },
                    message: { Text(notes.errorMessage ?? "") }
                )
        }
    }

    private var title: String {
        notes.isSelecting ? "\(notes.selectedIDs.count)개 선택됨" : "DROP"
    }

    @ViewBuilder
    private var content: some View {
        if notes.isLoading, notes.visibleNotes.isEmpty {
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if notes.visibleNotes.isEmpty {
            emptyState
        } else {
            list
        }
    }

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: DropTheme.Spacing.base) {
                ForEach(notes.visibleNotes) { note in
                    NoteCard(
                        note: note,
                        isSelected: notes.selectedIDs.contains(note.id),
                        isSelecting: notes.isSelecting
                    )
                    .onTapGesture {
                        if notes.isSelecting {
                            notes.toggleSelection(id: note.id)
                        } else {
                            composer = .existing(note)
                        }
                    }
                    .onLongPressGesture {
                        notes.toggleSelection(id: note.id)
                    }
                    .swipeActionsCompat {
                        Button(role: .destructive) {
                            Task { await notes.moveToTrash(id: note.id) }
                        } label: {
                            Label("삭제", systemImage: "trash")
                        }
                        Button {
                            Task { await notes.setPinned(id: note.id, isPinned: !note.isPinned) }
                        } label: {
                            Label(note.isPinned ? "고정 해제" : "고정", systemImage: "pin")
                        }
                        .tint(.orange)
                    }
                }
            }
            .padding(.horizontal, DropTheme.Spacing.comfortable)
            .padding(.vertical, DropTheme.Spacing.base)
        }
    }

    private var emptyState: some View {
        VStack(spacing: DropTheme.Spacing.comfortable) {
            Image(systemName: emptyIcon)
                .font(.largeTitle)
                .foregroundStyle(.tertiary)
            Text(emptyMessage)
                .font(.callout)
                .foregroundStyle(.secondary)
            if notes.viewMode == .active, notes.searchText.isEmpty {
                Button("첫 노트 쓰기") { composer = .new }
                    .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyIcon: String {
        switch notes.viewMode {
        case .active: "tray"
        case .archived: "archivebox"
        case .trash: "trash"
        }
    }

    private var emptyMessage: String {
        if !notes.searchText.isEmpty { return "검색 결과가 없습니다" }
        return switch notes.viewMode {
        case .active: "아직 노트가 없습니다"
        case .archived: "보관한 노트가 없습니다"
        case .trash: "휴지통이 비어 있습니다"
        }
    }

    private var filters: some View {
        NoteFilterBar(store: notes)
            .background(.bar)
    }

    @ViewBuilder
    private var bottomBar: some View {
        if notes.isSelecting {
            SelectionActionBar(store: notes)
        } else {
            HStack {
                Spacer()
                Button {
                    composer = .new
                } label: {
                    Image(systemName: "plus")
                        .font(.title2.weight(.semibold))
                        .frame(width: 56, height: 56)
                }
                .buttonStyle(.borderedProminent)
                .clipShape(Circle())
                .padding(DropTheme.Spacing.loose)
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        if notes.isSelecting {
            ToolbarItem(placement: .topBarLeading) {
                Button("취소") { notes.clearSelection() }
            }
        } else {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    NavigationLink { TagsView(store: notes) } label: {
                        Label("태그", systemImage: "number")
                    }
                    Button("로그아웃", systemImage: "rectangle.portrait.and.arrow.right") {
                        Task { await auth.signOut() }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
    }
}

/// iOS 17에서는 `swipeActions`가 `List` 안에서만 동작한다.
/// 카드 레이아웃(LazyVStack)에서도 같은 동작을 주기 위해 컨텍스트 메뉴로 대체한다.
private extension View {
    func swipeActionsCompat<Content: View>(@ViewBuilder _ actions: () -> Content) -> some View {
        contextMenu { actions() }
    }
}

enum ComposerTarget: Identifiable {
    case new
    case existing(Note)

    var id: String {
        switch self {
        case .new: "새-노트"
        case let .existing(note): note.id
        }
    }
}
