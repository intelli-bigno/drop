import DropCore
import DropUI
import SwiftUI

/// `widgets/note_composer_sheet.dart` 대응. DROP의 핵심 동선 — 빠르게 던져넣기.
struct NoteComposerSheet: View {
    let target: ComposerTarget
    let onSubmit: (String) async -> Void

    @Environment(\.dismiss) private var dismiss
    @FocusState private var isFocused: Bool
    @State private var text: String
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
            // **에디터는 종이다.** 글을 쓰는 자리에 유리를 깔면 뒤에 흐르는
            // 목록이 글자 사이로 비쳐 읽기가 무너진다 (BRU-75).
            TextEditor(text: $text)
                .focused($isFocused)
                .font(.body)
                .foregroundStyle(DropTokens.Colors.textPrimary)
                .scrollContentBackground(.hidden)
                .background(DropTheme.Surface.page)
                .padding(.horizontal, DropTheme.Spacing.comfortable)
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("닫기") { dismiss() }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(isNew ? "추가" : "저장") { submit() }
                            // 저장 중 중복 탭을 막지 않으면 노트가 두 번 만들어진다.
                            .disabled(isSaving || trimmed.isEmpty)
                            .fontWeight(.semibold)
                    }
                }
                // 시트가 뜨자마자 키보드가 올라와야 "던져넣기"가 끊기지 않는다.
                .onAppear { isFocused = true }
        }
        .presentationDetents([.medium, .large])
        // 시트의 툴바는 시스템이 유리로 그린다 — 여기서 할 일은 그 아래를
        // 종이로 두는 것뿐이다.
        .presentationBackground(DropTheme.Surface.page)
        .tint(DropTokens.Colors.accent)
        .interactiveDismissDisabled(isSaving)
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
