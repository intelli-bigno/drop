import DropCore
import DropUI
import PhotosUI
import SwiftUI

/// `screens/home_screen.dart` 대응. 앱 사용 시간의 대부분이 여기다.
struct HomeView: View {
    /// 날짜 섹션 묶기는 DropCore의 순수 함수가 한다 — 자정·시간대 경계를
    /// 화면 코드에 두면 검증할 방법이 없다.
    private static let grouper = NoteDateGrouper()

    @Environment(AuthStore.self) private var auth
    @Environment(DropRouter.self) private var router
    @Environment(\.dropContainer) private var container
    @Environment(\.scenePhase) private var scenePhase
    @State private var notes: NotesStore
    /// 댓글은 노트가 아니므로 상태도 따로 둔다 — `NotesStore`에 섞을 길을 만들지 않는다.
    @State private var comments: CommentsStore
    @State private var composer: ComposerTarget?
    /// 댓글 시트를 띄울 노트.
    @State private var commentTarget: Note?
    @State private var photoSelection: [PhotosPickerItem] = []
    @State private var viewingAttachments: AttachmentPresentation?
    /// 썸네일용 서명 URL 캐시. 스크롤할 때마다 다시 발급받지 않기 위해 화면 단위로 하나 둔다.
    @State private var attachmentURLs: AttachmentURLCache?

    /// 프리뷰 모드에서는 컨테이너가 없어 서명 URL을 받을 수 없다.
    /// 그 경우에만 대체 제공자를 받아 썸네일 경로를 그대로 태워 본다.
    private let previewAttachmentURL: ((Attachment) -> URL?)?

    init(
        repository: any NotesRepository,
        commentsRepository: any CommentsRepository,
        previewAttachmentURL: ((Attachment) -> URL?)? = nil
    ) {
        _notes = State(wrappedValue: NotesStore(repository: repository))
        _comments = State(wrappedValue: CommentsStore(repository: commentsRepository))
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
                    // 뱃지 숫자는 노트 목록과 별개의 왕복 한 번으로 받는다.
                    // 실패해도 목록은 그대로 뜬다 — 뱃지가 없는 것이 목록이 없는 것보다 낫다.
                    await comments.loadCounts()
                    // 공유 시트로 들어온 항목을 여기서 비운다. 확장은 적어 두기만 한다.
                    await drainSharedInbox()
                }
                // 목록이 바뀌는 경로가 여럿이라(불러오기·작성·수정·삭제) 각 호출부에
                // 끼워 넣지 않고, 결과인 목록 자체를 한 곳에서 본다.
                .onChange(of: notes.allNotes, initial: true) { _, all in
                    WidgetSnapshotPublisher.publish(notes: all)
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
                .sheet(item: $commentTarget) { note in
                    CommentsSheet(note: note, store: comments)
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
        if notes.isSelecting { return "\(notes.selectedIDs.count)개 선택됨" }
        // 보기 전환이 ⋯ 메뉴로 들어가 화면에 안 보이므로, 지금 어디를 보고 있는지는
        // 제목이 알려 준다. 안 그러면 휴지통에서 "노트가 사라졌다"고 읽힌다.
        return switch notes.viewMode {
        case .active: "DROP"
        case .archived: "보관"
        case .trash: "휴지통"
        }
    }

    private var viewMode: Binding<NoteViewMode> {
        Binding(get: { notes.viewMode }, set: { notes.viewMode = $0 })
    }

    /// **스크롤 컨테이너는 항상 하나, 항상 여기 있다.**
    /// 예전에는 로딩·빈 상태에서 스크롤 컨테이너가 아예 없는 뷰(ProgressView / VStack)로
    /// 갈라졌고, `.refreshable`은 그 바깥에 붙어 있었다 — 당길 대상이 없으니
    /// 새로고침이 아예 걸리지 않았다(PR #40). 갈림길은 컨테이너 **안쪽**에 둔다.
    ///
    /// 컨테이너가 ScrollView에서 List로 바뀌었을 뿐 그 불변식은 그대로다.
    /// List로 옮긴 이유는 하나 — `.swipeActions`가 List 안에서만 동작하기 때문이다.
    /// 예전에는 그래서 `contextMenu`로 흉내 냈고, 스와이프는 실제로 없었다.
    private var content: some View {
        List {
            if notes.isLoading, notes.visibleNotes.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .containerRelativeFrame(.vertical)
                    .plainListRow()
            } else if notes.visibleNotes.isEmpty {
                emptyState
                    .containerRelativeFrame(.vertical)
                    .plainListRow()
            } else {
                noteSections
            }
        }
        .listStyle(.plain)
        // 한 줄 행은 기본 최소 높이(44)보다 낮다. 기본값이면 행 사이가 벌어진다.
        .environment(\.defaultMinListRowHeight, 0)
        // 내용이 화면보다 짧아도 당길 수 있어야 한다 — 새로고침이 가장 필요한 곳이
        // 목록이 비어 보이는 순간이다. 기본값이면 짧은 내용에서 튐이 죽는다.
        .scrollBounceBehavior(.always, axes: .vertical)
        .refreshable { await notes.load() }
    }

    private var noteSections: some View {
        ForEach(Self.grouper.sections(for: notes.visibleNotes)) { section in
            Section {
                ForEach(section.notes) { note in
                    noteRow(for: note)
                }
            } header: {
                Text(section.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(nil)
                    .listRowInsets(EdgeInsets(
                        top: DropTheme.Spacing.base,
                        leading: DropTheme.Spacing.comfortable,
                        bottom: DropTheme.Spacing.tight,
                        trailing: DropTheme.Spacing.comfortable
                    ))
            }
        }
    }

    private func noteRow(for note: Note) -> some View {
        NoteCard(
            note: note,
            isSelected: notes.selectedIDs.contains(note.id),
            isSelecting: notes.isSelecting,
            commentCount: comments.count(for: note.id),
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
        // 롱프레스는 선택 모드 하나만 쓴다. 예전에는 같은 롱프레스를
        // contextMenu(스와이프 대체)가 함께 노려 어느 쪽이 뜰지 들쭉날쭉했다.
        .onLongPressGesture {
            notes.toggleSelection(id: note.id)
        }
        // 실수로 지우는 일이 없게 전체 스와이프는 막는다 — 휴지통이라도 한 번 더 확인이 낫다.
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
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
        // 댓글은 왼쪽에서 연다 — 오른쪽(삭제·고정)은 노트 자체를 다루는 자리고,
        // 댓글은 노트를 건드리지 않는 동작이라 방향을 갈라 놓는다.
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                commentTarget = note
            } label: {
                Label("댓글", systemImage: "bubble.left")
            }
            .tint(.blue)
        }
        .plainListRow(
            insets: EdgeInsets(
                top: DropTheme.Spacing.tight / 2,
                leading: DropTheme.Spacing.comfortable,
                bottom: DropTheme.Spacing.tight / 2,
                trailing: DropTheme.Spacing.comfortable
            )
        )
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
            // 두 버튼을 하나의 떠 있는 묶음으로 둔다.
            // 크기가 제각각인 원이 흩어져 있으면 어느 것이 주 동작인지 읽히지 않는다.
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
                    // 필터바에서 세그먼트를 걷어내고 여기로 옮겼다 — 보기 전환은
                    // 하루에 몇 번 쓰지 않는데 목록 한 줄을 상시로 먹고 있었다.
                    Picker("보기", selection: viewMode) {
                        Label("노트", systemImage: "tray").tag(NoteViewMode.active)
                        Label("보관", systemImage: "archivebox").tag(NoteViewMode.archived)
                        Label("휴지통", systemImage: "trash").tag(NoteViewMode.trash)
                    }
                    .pickerStyle(.inline)

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
    /// 공유 시트로 들어온 항목을 노트로 만든다.
    ///
    /// 앱 안에서 녹음하는 경로는 BRU-48에서 없앴지만, **오디오가 노트로 들어오는
    /// 길은 여기 하나가 남아 있다** — 다른 앱에서 공유한 음성 파일은 그대로
    /// `.audio` 첨부가 된다(`AttachmentType.forFileName`).
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

/// List가 기본으로 그리는 구분선·행 배경·여백을 걷어낸다.
/// 행의 둥근 배경은 `NoteCard`가 직접 그린다 — 둘이 겹치면 카드 밖에 회색 판이 하나 더 깔린다.
private extension View {
    func plainListRow(insets: EdgeInsets = EdgeInsets()) -> some View {
        listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            .listRowInsets(insets)
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
