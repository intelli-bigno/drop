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
    /// 썸네일용 서명 URL 캐시. 스크롤할 때마다 다시 발급받지 않기 위해 화면 단위로 하나 둔다.
    @State private var attachmentURLs: AttachmentURLCache?

    /// 프리뷰 모드에서는 컨테이너가 없어 서명 URL을 받을 수 없다.
    /// 그 경우에만 대체 제공자를 받아 썸네일 경로를 그대로 태워 본다.
    private let previewAttachmentURL: ((Attachment) -> URL?)?

    init(
        repository: any NotesRepository,
        previewAttachmentURL: ((Attachment) -> URL?)? = nil
    ) {
        _notes = State(wrappedValue: NotesStore(repository: repository))
        self.previewAttachmentURL = previewAttachmentURL
    }

    var body: some View {
        @Bindable var notes = notes

        NavigationStack {
            content
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                // .searchable을 쓰면 iOS 26에서 검색창이 화면 하단에 붙어
                // 액션 버튼과 겹친다. 검색은 필터 줄 안에 직접 둔다.
                .toolbar { toolbar }
                .safeAreaInset(edge: .top, spacing: 0) { filters }
                .safeAreaInset(edge: .bottom) { bottomBar }
                .task {
                    if attachmentURLs == nil, let container {
                        attachmentURLs = AttachmentURLCache(repository: container.makeAttachmentsRepository())
                    }
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
                    MediaViewer(
                        attachments: presentation.attachments,
                        urlProvider: attachmentURL,
                        current: presentation.current
                    )
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

    /// 썸네일·뷰어가 함께 쓰는 이미지 URL 제공자.
    private func attachmentURL(_ attachment: Attachment) async -> URL? {
        if let previewAttachmentURL { return previewAttachmentURL(attachment) }
        return await attachmentURLs?.url(for: attachment.storagePath)
    }

    private var title: String {
        notes.isSelecting ? "\(notes.selectedIDs.count)개 선택됨" : "DROP"
    }

    /// **스크롤 컨테이너는 항상 하나, 항상 여기 있다.**
    /// 예전에는 로딩·빈 상태에서 ScrollView가 아예 없는 뷰(ProgressView / VStack)로
    /// 갈라졌고, `.refreshable`은 그 바깥에 붙어 있었다 — 당길 대상이 없으니
    /// 새로고침이 아예 걸리지 않았다. 갈림길은 스크롤뷰 **안쪽**으로 옮긴다.
    private var content: some View {
        ScrollView {
            if notes.isLoading, notes.visibleNotes.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .containerRelativeFrame(.vertical)
            } else if notes.visibleNotes.isEmpty {
                emptyState
                    .containerRelativeFrame(.vertical)
            } else {
                noteList
            }
        }
        // 내용이 화면보다 짧아도 당길 수 있어야 한다 — 새로고침이 가장 필요한 곳이
        // 목록이 비어 보이는 순간이다. 기본값이면 짧은 내용에서 튐이 죽는다.
        .scrollBounceBehavior(.always, axes: .vertical)
        .refreshable { await notes.load() }
    }

    private var noteList: some View {
        LazyVStack(spacing: DropTheme.Spacing.base) {
            ForEach(notes.visibleNotes) { note in
                NoteCard(
                    note: note,
                    isSelected: notes.selectedIDs.contains(note.id),
                    isSelecting: notes.isSelecting,
                    attachmentURL: attachmentURL,
                    onOpenAttachment: { attachment in
                        viewingAttachments = AttachmentPresentation(
                            attachments: note.attachments.filter { $0.isImage || $0.isVideo },
                            current: attachment
                        )
                    }
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
            // 세 버튼을 하나의 떠 있는 묶음으로 둔다.
            // 크기가 제각각인 원 세 개가 흩어져 있으면 어느 것이 주 동작인지 읽히지 않는다.
            HStack(spacing: 0) {
                Spacer()

                HStack(spacing: DropTheme.Spacing.comfortable) {
                    PhotosPicker(
                        selection: $photoSelection,
                        maxSelectionCount: 5,
                        matching: .any(of: [.images, .videos])
                    ) {
                        Image(systemName: "photo.on.rectangle")
                            .font(.system(size: 20))
                            .frame(width: 44, height: 44)
                            .contentShape(Circle())
                    }
                    .foregroundStyle(.primary)

                    Button {
                        isRecording = true
                    } label: {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 20))
                            .frame(width: 44, height: 44)
                            .contentShape(Circle())
                    }
                    .foregroundStyle(.primary)

                    Button {
                        composer = .new
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 22, weight: .semibold))
                            .frame(width: 52, height: 52)
                            .background(Color.accentColor, in: Circle())
                            .foregroundStyle(.white)
                    }
                }
                .padding(.horizontal, DropTheme.Spacing.base)
                .padding(.vertical, DropTheme.Spacing.base)
                .background(.regularMaterial, in: Capsule())
                .overlay(Capsule().stroke(Color.primary.opacity(0.08)))
                .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
            }
            .padding(.horizontal, DropTheme.Spacing.loose)
            .padding(.bottom, DropTheme.Spacing.base)
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
