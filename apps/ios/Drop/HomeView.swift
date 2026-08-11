import DropCore
import DropUI
import PhotosUI
import SwiftUI

/// `screens/home_screen.dart` 대응. 앱 사용 시간의 대부분이 여기다.
struct HomeView: View {
    @Environment(AuthStore.self) private var auth
    @Environment(DropRouter.self) private var router
    @Environment(\.dropContainer) private var container
    @Environment(\.scenePhase) private var scenePhase
    @State private var notes: NotesStore
    @State private var composer: ComposerTarget?
    @State private var isRecording = false
    @State private var photoSelection: [PhotosPickerItem] = []
    @State private var viewingAttachments: AttachmentPresentation?

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
                .task {
                    await notes.load()
                    // 공유 시트로 들어온 항목을 여기서 비운다. 확장은 적어 두기만 한다.
                    await drainSharedInbox()
                }
                .onChange(of: scenePhase) { _, phase in
                    // 앱이 살아 있는 채로 공유가 들어오면 복귀 시점에 비운다.
                    guard phase == .active else { return }
                    Task { await drainSharedInbox() }
                }
                .onChange(of: router.pendingComposeText) { _, text in
                    guard text != nil else { return }
                    composer = .newWithText(router.consumeComposeText() ?? "")
                }
                .sheet(item: $composer) { target in
                    NoteComposerSheet(target: target) { content in
                        switch target {
                        case .new, .newWithText:
                            await notes.create(content: content)
                        case let .existing(note):
                            await notes.update(id: note.id, content: content)
                        }
                    }
                }
                .sheet(isPresented: $isRecording) {
                    RecordingSheet { url, transcript in
                        await addAudioNote(fileURL: url, transcript: transcript)
                    }
                }
                .sheet(item: $viewingAttachments) { presentation in
                    MediaViewer(attachments: presentation.attachments, current: presentation.current)
                }
                .onChange(of: photoSelection) { _, items in
                    guard !items.isEmpty else { return }
                    Task { await addPhotoNote(items: items) }
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
            HStack(spacing: DropTheme.Spacing.comfortable) {
                Spacer()

                PhotosPicker(selection: $photoSelection, maxSelectionCount: 5, matching: .any(of: [.images, .videos])) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.title3)
                        .frame(width: 48, height: 48)
                }
                .buttonStyle(.bordered)
                .clipShape(Circle())

                Button {
                    isRecording = true
                } label: {
                    Image(systemName: "mic.fill")
                        .font(.title3)
                        .frame(width: 48, height: 48)
                }
                .buttonStyle(.bordered)
                .clipShape(Circle())

                Button {
                    composer = .new
                } label: {
                    Image(systemName: "plus")
                        .font(.title2.weight(.semibold))
                        .frame(width: 56, height: 56)
                }
                .buttonStyle(.borderedProminent)
                .clipShape(Circle())
            }
            .padding(DropTheme.Spacing.loose)
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

private extension HomeView {
    /// 녹음 노트: 전사 텍스트를 본문으로 넣고 오디오를 첨부한다.
    /// 전사에 실패했으면 본문이 비지만, **녹음 자체는 남는다** — 여기서 막으면
    /// 사용자가 방금 말한 내용을 통째로 잃는다.
    func addAudioNote(fileURL: URL, transcript: String?) async {
        await notes.create(content: transcript ?? "")
        guard let container, let note = notes.visibleNotes.first else { return }

        do {
            let data = try Data(contentsOf: fileURL)
            _ = try await container.makeAttachmentsRepository().upload(
                data: data,
                fileName: fileURL.lastPathComponent,
                type: .audio,
                toNote: note.id
            )
            try? FileManager.default.removeItem(at: fileURL)
            await notes.load()
        } catch {
            notes.report(error: error)
        }
    }

    /// 공유 시트로 들어온 항목을 노트로 만든다.
    ///
    /// 첨부 업로드가 실패해도 노트는 남긴다 — 사용자가 공유한 텍스트/링크까지
    /// 함께 잃는 것이 더 나쁘다.
    func drainSharedInbox() async {
        guard let inbox = SharedInbox(), let container else { return }
        let items = (try? inbox.drain()) ?? []
        guard !items.isEmpty else { return }

        let attachments = container.makeAttachmentsRepository()
        for item in items {
            await notes.create(content: item.text)
            guard let note = notes.visibleNotes.first else { continue }

            for fileName in item.fileNames {
                let url = inbox.fileURL(named: fileName)
                do {
                    let data = try Data(contentsOf: url)
                    _ = try await attachments.upload(
                        data: data,
                        fileName: fileName,
                        type: AttachmentType.forFileName(fileName),
                        toNote: note.id
                    )
                } catch {
                    notes.report(error: error)
                }
                try? FileManager.default.removeItem(at: url)
            }
        }
        await notes.load()
    }

    func addPhotoNote(items: [PhotosPickerItem]) async {
        defer { photoSelection = [] }
        await notes.create(content: "")
        guard let container, let note = notes.visibleNotes.first else { return }

        let repository = container.makeAttachmentsRepository()
        for item in items {
            do {
                guard let data = try await item.loadTransferable(type: Data.self) else { continue }
                let isVideo = item.supportedContentTypes.contains { $0.conforms(to: .movie) }
                _ = try await repository.upload(
                    data: data,
                    fileName: item.itemIdentifier ?? (isVideo ? "video.mp4" : "image.jpg"),
                    type: isVideo ? .video : .image,
                    toNote: note.id
                )
            } catch {
                notes.report(error: error)
            }
        }
        await notes.load()
    }
}

struct AttachmentPresentation: Identifiable {
    let attachments: [Attachment]
    let current: Attachment

    var id: String { current.id }
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
    /// 딥링크로 들어온 초안 — 본문이 미리 채워진 채로 열린다.
    case newWithText(String)
    case existing(Note)

    var id: String {
        switch self {
        case .new: "새-노트"
        case let .newWithText(text): "새-노트-\(text.hashValue)"
        case let .existing(note): note.id
        }
    }
}
