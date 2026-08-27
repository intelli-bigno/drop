import DropCore
import DropUI
import PhotosUI
import SwiftUI

/// `widgets/note_composer_sheet.dart` 대응. DROP의 핵심 동선 — 빠르게 던져넣기.
///
/// 본문은 평문 마크다운이다. 여기서 쓰고(툴바), 여기서 읽는다(미리보기) —
/// 목록은 한 줄만 보여 주므로 노트를 다 읽는 자리도 결국 이 시트다 (BRU-37, BRU-49).
struct NoteComposerSheet: View {
    let target: ComposerTarget
    let onSubmit: (String, [PendingAttachment]) async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var text: String
    /// 커서 위치. 툴바가 "고른 글자를 굵게"를 하려면 이 값이 있어야 한다.
    @State private var selection = NSRange(location: 0, length: 0)
    @State private var isPreviewing = false
    @State private var isSaving = false
    @State private var pickerItems: [PhotosPickerItem] = []
    /// 노트 id가 생기기 전에 고른 파일. 제출 때 함께 넘긴다 (BRU-131).
    @State private var pending: [PendingAttachment] = []

    init(target: ComposerTarget, onSubmit: @escaping (String, [PendingAttachment]) async -> Void) {
        self.target = target
        self.onSubmit = onSubmit
        switch target {
        case let .existing(note): _text = State(initialValue: note.content)
        case let .newWithText(text): _text = State(initialValue: text)
        case .new, .reply: _text = State(initialValue: "")
        }
    }

    var body: some View {
        NavigationStack {
            // **에디터는 종이다.** 글을 쓰는 자리에 유리를 깔면 뒤에 흐르는
            // 목록이 글자 사이로 비쳐 읽기가 무너진다 (BRU-75).
            editorOrPreview
                .padding(.horizontal, DropTheme.Spacing.comfortable)
                .background(DropTheme.Surface.page)
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                // 닫기·미리보기·추가/저장은 키보드 위 하단으로 옮겼다 (BRU-132).
                // 상단은 제목만 남긴다.
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    VStack(spacing: 0) {
                        // 툴바는 키보드 위에 붙는다. 미리보기 중에는 칠 것이 없으니 걷는다.
                        if !isPreviewing {
                            MarkdownToolbar(onCommand: apply)
                        }
                        composerActions
                    }
                }
                .onChange(of: pickerItems) { _, items in
                    guard !items.isEmpty else { return }
                    Task { await ingest(items) }
                }
        }
        .presentationDetents([.medium, .large])
        // 시트의 툴바는 시스템이 유리로 그린다 — 여기서 할 일은 그 아래를
        // 종이로 두는 것뿐이다.
        .presentationBackground(DropTheme.Surface.page)
        .tint(DropTokens.Colors.accent)
        .interactiveDismissDisabled(isSaving)
    }

    @ViewBuilder
    private var editorOrPreview: some View {
        if isPreviewing {
            ScrollView {
                MarkdownText(text)
                    .padding(.vertical, DropTheme.Spacing.base)
            }
            .scrollContentBackground(.hidden)
        } else {
            // 시트가 뜨자마자 키보드가 올라와야 "던져넣기"가 끊기지 않는다.
            MarkdownSourceEditor(text: $text, selection: $selection, focusesOnAppear: true)
        }
    }

    /// 닫기 / 미리보기 / 사진 / 추가(저장). 키보드 바로 위, 마크다운 툴바 옆 (BRU-132).
    private var composerActions: some View {
        HStack(spacing: DropTheme.Spacing.base) {
            Button("닫기") { dismiss() }
                .accessibilityIdentifier("닫기")
                .disabled(isSaving)

            previewToggle

            PhotosPicker(
                selection: $pickerItems,
                maxSelectionCount: 5,
                matching: .any(of: [.images, .videos])
            ) {
                Image(systemName: "photo.on.rectangle")
                    .font(.subheadline)
                    .frame(width: 40, height: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(DropTokens.Colors.textPrimary)
            .accessibilityLabel("사진 첨부")
            .accessibilityIdentifier("사진 첨부")
            .disabled(isSaving)

            if !pending.isEmpty {
                Text("첨부 \(pending.count)")
                    .font(.caption)
                    .foregroundStyle(DropTokens.Colors.textSecondary)
                    .accessibilityIdentifier("대기 첨부")
            }

            Spacer()

            Button(isNew ? "추가" : "저장") { submit() }
                // 저장 중 중복 탭을 막지 않으면 노트가 두 번 만들어진다.
                // 본문이 비어도 고른 파일이 있으면 제출할 수 있다 (BRU-131).
                .disabled(isSaving || !canSubmit)
                .fontWeight(.semibold)
                .accessibilityIdentifier(isNew ? "추가" : "저장")
        }
        .padding(.horizontal, DropTheme.Spacing.comfortable)
        .padding(.vertical, DropTheme.Spacing.tight)
        .frame(minHeight: 44)
        // 키보드 위 액션 줄은 기능 레이어라 유리다 (BRU-75).
        .glassEffect(.regular, in: Rectangle())
    }

    /// 편집↔미리보기 전환.
    ///
    /// **미리보기는 읽기만 한다.** 이 버튼은 화면 상태(`isPreviewing`)만 바꾸고
    /// `text`도 저장 경로도 건드리지 않는다 — 열람했더니 본문이 달라져 있는 일이
    /// 다시 생기면 안 된다 (BRU-66).
    private var previewToggle: some View {
        Button {
            isPreviewing.toggle()
        } label: {
            Image(systemName: isPreviewing ? "pencil" : "eye")
        }
        .accessibilityLabel(isPreviewing ? "편집" : "미리보기")
        // 이름은 상태에 따라 바뀐다 — 게다가 "편집"은 뷰어(NoteDetailView)의 버튼과
        // 겹친다. 컴포저가 뷰어 위에 뜨는 지금(BRU-77) 이름으로 찾으면 어느 쪽을
        // 잡을지 알 수 없으므로, 검증이 붙잡을 고정 손잡이를 따로 준다.
        .accessibilityIdentifier("미리보기 전환")
        .disabled(isSaving)
    }

    /// 툴바 명령을 본문에 적용한다. 무엇을 어디에 끼워 넣을지는 전부
    /// `DropCore`의 `MarkdownEditor`가 정한다 — 화면은 결과만 받아 든다.
    private func apply(_ command: MarkdownEditingCommand) {
        let result = MarkdownEditor.apply(command, to: text, selection: selection)
        text = result.text
        selection = result.selection
    }

    private func ingest(_ items: [PhotosPickerItem]) async {
        defer { pickerItems = [] }
        for item in items {
            guard let data = try? await item.loadTransferable(type: Data.self) else { continue }
            let isVideo = item.supportedContentTypes.contains { $0.conforms(to: .movie) }
            pending.append(PendingAttachment(
                data: data,
                fileName: item.itemIdentifier ?? (isVideo ? "video.mp4" : "image.jpg"),
                type: isVideo ? .video : .image
            ))
        }
    }

    private var isNew: Bool {
        if case .existing = target { return false }
        return true
    }

    /// 어느 노트에 딸리는 글인지 제목으로 알려 준다 — 답글 시트는 새 노트 시트와
    /// 생김새가 같아서, 표시가 없으면 무엇을 쓰는 중인지 알 수 없다 (BRU-69).
    private var title: String {
        switch target {
        case .existing: "노트 편집"
        case let .reply(parent): "답글 — \(parent.displayID > 0 ? "#\(parent.displayID)" : "노트")"
        case .new, .newWithText: "새 노트"
        }
    }

    private var trimmed: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSubmit: Bool {
        !trimmed.isEmpty || !pending.isEmpty
    }

    private func submit() {
        guard !isSaving, canSubmit else { return }
        isSaving = true
        let content = trimmed
        let attachments = pending
        Task {
            await onSubmit(content, attachments)
            isSaving = false
            dismiss()
        }
    }
}
