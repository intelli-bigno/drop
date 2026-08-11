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
        case .new: _text = State(initialValue: "")
        }
    }

    var body: some View {
        NavigationStack {
            TextEditor(text: $text)
                .focused($isFocused)
                .font(.body)
                .padding(.horizontal, DropTheme.Spacing.comfortable)
                .navigationTitle(isNew ? "새 노트" : "노트 편집")
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
        .interactiveDismissDisabled(isSaving)
    }

    private var isNew: Bool {
        if case .existing = target { return false }
        return true
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
