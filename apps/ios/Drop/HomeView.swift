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
    /// 펼쳐 볼 노트 (BRU-77). 노트 자체가 아니라 id를 들고 있는다 —
    /// 뷰어가 떠 있는 동안 노트가 바뀌면(편집 저장) 새 값이 그려져야 한다.
    @State private var detailTarget: NoteDetailTarget?
    /// 댓글 시트를 띄울 노트.
    @State private var commentTarget: Note?
    @State private var photoSelection: [PhotosPickerItem] = []
    /// 위젯의 갤러리 바로가기로 들어왔을 때 여는 사진 보관함 (BRU-43).
    @State private var isPickingPhotos = false
    /// 위젯의 카메라 바로가기.
    @State private var isCapturing = false
    @State private var cameraUnavailable = false
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
                // 위젯의 카메라·갤러리 바로가기 (BRU-43). 화면 안의 버튼과 같은 경로로 보낸다 —
                // 위젯 전용 첨부 경로를 따로 만들면 두 길이 어긋난다.
                .onChange(of: router.pendingCapture) { _, capture in
                    guard capture != nil else { return }
                    switch router.consumeCapture() {
                    case .camera:
                        if CameraPicker.isAvailable {
                            isCapturing = true
                        } else {
                            cameraUnavailable = true
                        }
                    case .gallery:
                        isPickingPhotos = true
                    case nil:
                        break
                    }
                }
                .photosPicker(
                    isPresented: $isPickingPhotos,
                    selection: $photoSelection,
                    maxSelectionCount: 5,
                    matching: .any(of: [.images, .videos])
                )
                .fullScreenCover(isPresented: $isCapturing) {
                    CameraPicker { data in
                        Task { await addCameraNote(data: data) }
                    }
                    .ignoresSafeArea()
                }
                .alert(
                    "카메라를 쓸 수 없습니다",
                    isPresented: $cameraUnavailable,
                    actions: { Button("확인") {} },
                    message: { Text("이 기기에서는 카메라를 열 수 없습니다. 사진 보관함에서 골라 주세요.") }
                )
                .sheet(item: $composer) { target in
                    NoteComposerSheet(target: target) { content in
                        switch target {
                        case .new, .newWithText:
                            await notes.create(content: content)
                        case let .existing(note):
                            await notes.update(id: note.id, content: content)
                        case let .reply(parent):
                            await notes.create(content: content, parentID: parent.id)
                        }
                    }
                }
                // 펼치기(뷰어). 읽기 전용 경로다 — 여기서는 저장이 일어나지 않는다 (BRU-77).
                .sheet(item: $detailTarget) { target in
                    if let note = notes.allNotes.first(where: { $0.id == target.id }) {
                        NoteDetailView(
                            note: note,
                            commentCount: comments.count(for: note.id),
                            comments: comments,
                            attachmentURL: attachmentURL,
                            onSubmitEdit: { content in await notes.update(id: note.id, content: content) },
                            onStateAction: { action in await perform(action, on: note) }
                        )
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
        // List가 스스로 까는 시스템 배경을 걷어내고 웜 페이퍼를 깐다 (BRU-75).
        // 여기는 콘텐츠 레이어라 유리가 아니라 종이다.
        .scrollContentBackground(.hidden)
        .background(DropTheme.Surface.page)
        // 한 줄 행은 기본 최소 높이(44)보다 낮다. 기본값이면 행 사이가 벌어진다.
        .environment(\.defaultMinListRowHeight, 0)
        // 내용이 화면보다 짧아도 당길 수 있어야 한다 — 새로고침이 가장 필요한 곳이
        // 목록이 비어 보이는 순간이다. 기본값이면 짧은 내용에서 튐이 죽는다.
        .scrollBounceBehavior(.always, axes: .vertical)
        .refreshable { await notes.load() }
    }

    private var noteSections: some View {
        ForEach(Self.grouper.sections(for: notes.visibleRows)) { section in
            Section {
                ForEach(section.rows) { row in
                    noteRow(for: row)
                }
            } header: {
                Text(section.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DropTokens.Colors.textSecondary)
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

    private func noteRow(for row: NoteRow) -> some View {
        let note = row.note
        return NoteCard(
            row: row,
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
        // 탭은 **펼치기**다. 편집기는 뷰어에서 "편집"을 한 번 더 눌러야 열린다 —
        // 열어 보려던 동작이 저장 경로를 건드리면 안 된다 (BRU-77 / BRU-66).
        // 선택 모드에서는 그대로 선택 토글.
        .onTapGesture {
            if notes.isSelecting {
                notes.toggleSelection(id: note.id)
            } else {
                detailTarget = NoteDetailTarget(id: note.id)
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
            .tint(DropTheme.SwipeAction.pin)
        }
        // 댓글·답글은 왼쪽에서 연다 — 오른쪽(삭제·고정)은 노트 자체를 다루는 자리고,
        // 이 둘은 노트를 건드리지 않고 옆에 덧붙이는 동작이라 방향을 갈라 놓는다.
        // 전체 스와이프는 첫 버튼(댓글)에 걸린다 — 더 자주 쓰는 쪽이다.
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                commentTarget = note
            } label: {
                Label("댓글", systemImage: "bubble.left")
            }
            .tint(DropTheme.SwipeAction.comment)
            Button {
                composer = .reply(parent: note)
            } label: {
                Label("답글", systemImage: "arrowshape.turn.up.left")
            }
            .tint(DropTheme.SwipeAction.reply)
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
                .foregroundStyle(DropTokens.Colors.textMuted)
            Text(emptyMessage)
                .font(.callout)
                .foregroundStyle(DropTokens.Colors.textSecondary)
            if notes.viewMode == .active, notes.searchText.isEmpty {
                Button("첫 노트 쓰기") { composer = .new }
                    .buttonStyle(.borderedProminent)
                    .tint(DropTokens.Colors.cta)
                    .foregroundStyle(DropTokens.Colors.textOnAccent)
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

    /// 필터 줄은 목록 위에 떠 있는 **기능 레이어**라 유리다 —
    /// 재질은 `NoteFilterBar`가 직접 들고 있다.
    private var filters: some View {
        NoteFilterBar(store: notes)
    }

    @ViewBuilder
    private var bottomBar: some View {
        if notes.isSelecting {
            SelectionActionBar(store: notes)
        } else {
            // 두 버튼을 하나의 떠 있는 묶음으로 둔다.
            // 크기가 제각각인 원이 흩어져 있으면 어느 것이 주 동작인지 읽히지 않는다.
            // 떠 있는 작성 버튼 묶음 — 콘텐츠 위에 얹히는 **기능 레이어**라 유리다.
            // `GlassEffectContainer`로 묶어야 두 유리가 서로를 알아보고
            // 가까워질 때 형태 전이를 공유한다. 따로 두면 각자 튄다.
            HStack(spacing: 0) {
                Spacer()

                GlassEffectContainer(spacing: DropTheme.Spacing.comfortable) {
                    HStack(spacing: DropTheme.Spacing.comfortable) {
                        PhotosPicker(
                            selection: $photoSelection,
                            maxSelectionCount: 5,
                            matching: .any(of: [.images, .videos])
                        ) {
                            Image(systemName: "photo.on.rectangle")
                                .font(.system(size: 20))
                                .frame(width: 48, height: 48)
                                .contentShape(Circle())
                        }
                        .foregroundStyle(DropTokens.Colors.textPrimary)
                        // 보조 동작이라 tint 없이 맑은 유리로 둔다.
                        .glassEffect(.regular.interactive(), in: Circle())

                        Button {
                            composer = .new
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 22, weight: .semibold))
                                .frame(width: 56, height: 56)
                                .foregroundStyle(DropTokens.Colors.textOnAccent)
                        }
                        // tint는 **액션 버튼에만** 얹는다. 바나 표면에 액센트를
                        // 물들이면 밝은 배경에서 대비가 무너진다 (BRU-75 함정).
                        .glassEffect(
                            .regular.tint(DropTokens.Colors.accent).interactive(),
                            in: Circle()
                        )
                    }
                }
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
    /// 뷰어에서 고른 상태 변경을 목록의 저장소로 넘긴다 (BRU-77).
    /// **본문은 여기서 다루지 않는다** — 뷰어에서 본문이 나가는 길은 편집기뿐이다.
    func perform(_ action: NoteViewerAction, on note: Note) async {
        switch action {
        case .archive: await notes.archive(id: note.id)
        case .unarchive: await notes.unarchive(id: note.id)
        case .trash: await notes.moveToTrash(id: note.id)
        case .restore: await notes.restore(id: note.id)
        case .deletePermanently: await notes.deletePermanently(id: note.id)
        // 편집·댓글은 뷰어가 제 시트로 처리한다 — 목록을 거치지 않는다.
        case .edit, .comments: break
        }
    }

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
            // 만들어진 노트를 그대로 받는다. 목록에서 되찾으면 고정 노트가
            // 맨 앞이라 남의 노트에 첨부가 붙는다 (BRU-43).
            guard let note = await notes.create(content: item.text) else { continue }

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

    /// 카메라로 찍은 한 장을 노트로 만든다 (BRU-43).
    /// 보관함에서 고른 사진과 같은 자리로 간다 — 빈 노트 하나에 첨부를 붙인다.
    func addCameraNote(data: Data) async {
        // 첨부는 **방금 만든 그 노트**에 붙인다. 목록 첫 줄로 되찾던 예전 코드는
        // 정렬 1순위가 `isPinned`라 고정 노트가 하나만 있어도 사진이 그리로 갔고,
        // 태그·검색 필터가 켜져 있으면 빈 노트가 `visibleNotes`에서 걸러져
        // 더 엉뚱한 노트에 붙었다 — 위젯 카메라 바로가기가 딱 그 경로다 (BRU-43).
        guard let container, let note = await notes.create(content: "") else { return }

        do {
            _ = try await container.makeAttachmentsRepository().upload(
                data: data,
                fileName: "camera-\(Int(Date().timeIntervalSince1970)).jpg",
                type: .image,
                toNote: note.id
            )
        } catch {
            notes.report(error: error)
        }
        await notes.load()
    }

    func addPhotoNote(items: [PhotosPickerItem]) async {
        defer { photoSelection = [] }
        guard let container, let note = await notes.create(content: "") else { return }

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

/// 뷰어가 볼 노트. 노트를 통째로 들고 있으면 편집 저장 뒤에도 옛 값이 남는다 —
/// id만 들고 목록에서 매번 찾는다 (BRU-77).
struct NoteDetailTarget: Identifiable, Equatable {
    let id: String
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
    /// 어느 노트에 딸린 새 노트를 쓴다 (BRU-69).
    case reply(parent: Note)

    var id: String {
        switch self {
        case .new: "새-노트"
        case let .newWithText(text): "새-노트-\(text.hashValue)"
        case let .existing(note): note.id
        case let .reply(parent): "답글-\(parent.id)"
        }
    }
}
