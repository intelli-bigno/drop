import DropCore
import DropUI
import SwiftUI

/// `widgets/note_composer_sheet.dart` 대응. DROP의 핵심 동선 — 빠르게 던져넣기.
///
/// 본문은 평문 마크다운이다. 여기서 쓰고(툴바), 여기서 읽는다(미리보기) —
/// 목록은 한 줄만 보여 주므로 노트를 다 읽는 자리도 결국 이 시트다 (BRU-37, BRU-49).
struct NoteComposerSheet: View {
    let target: ComposerTarget
    let onSubmit: (String) async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var text: String
    /// 커서 위치. 툴바가 "고른 글자를 굵게"를 하려면 이 값이 있어야 한다.
    @State private var selection = NSRange(location: 0, length: 0)
    @State private var isPreviewing = false
    @State private var isSaving = false

    init(target: ComposerTarget, onSubmit: @escaping (String) async -> Void) {
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
            editorOrPreview
                .padding(.horizontal, DropTheme.Spacing.comfortable)
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("닫기") { dismiss() }
                    }
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        previewToggle
                        Button(isNew ? "추가" : "저장") { submit() }
                            // 저장 중 중복 탭을 막지 않으면 노트가 두 번 만들어진다.
                            .disabled(isSaving || trimmed.isEmpty)
                            .fontWeight(.semibold)
                    }
                }
                // 툴바는 키보드 위에 붙는다. 미리보기 중에는 칠 것이 없으니 걷는다.
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    if !isPreviewing {
                        MarkdownToolbar(onCommand: apply)
                    }
                }
        }
        .presentationDetents([.medium, .large])
        .interactiveDismissDisabled(isSaving)
    }

    @ViewBuilder
    private var editorOrPreview: some View {
        if isPreviewing {
            ScrollView {
                MarkdownText(text)
                    .padding(.vertical, DropTheme.Spacing.base)
            }
        } else {
            // 시트가 뜨자마자 키보드가 올라와야 "던져넣기"가 끊기지 않는다.
            MarkdownSourceEditor(text: $text, selection: $selection, focusesOnAppear: true)
        }
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
    }

    /// 툴바 명령을 본문에 적용한다. 무엇을 어디에 끼워 넣을지는 전부
    /// `DropCore`의 `MarkdownEditor`가 정한다 — 화면은 결과만 받아 든다.
    private func apply(_ command: MarkdownEditingCommand) {
        let result = MarkdownEditor.apply(command, to: text, selection: selection)
        text = result.text
        selection = result.selection
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

    private func submit() {
        guard !isSaving else { return }
        isSaving = true
        let content = trimmed
        Task {
            await onSubmit(content)
            isSaving = false
            dismiss()
        }
    }
}
