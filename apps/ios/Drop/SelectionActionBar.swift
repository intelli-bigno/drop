import DropCore
import DropUI
import SwiftUI

/// `widgets/selection_action_bar.dart` 대응.
/// 보고 있는 뷰 모드에 따라 할 수 있는 일이 달라진다 — 휴지통에서 "보관"은 뜻이 없다.
struct SelectionActionBar: View {
    let store: NotesStore

    var body: some View {
        HStack(spacing: DropTheme.Spacing.loose) {
            switch store.viewMode {
            case .active:
                action("보관", systemImage: "archivebox") {
                    await forEachSelected { await store.archive(id: $0) }
                }
                action("삭제", systemImage: "trash", role: .destructive) {
                    await store.trashSelected()
                }
            case .archived:
                action("복원", systemImage: "arrow.uturn.backward") {
                    await forEachSelected { await store.unarchive(id: $0) }
                }
                action("삭제", systemImage: "trash", role: .destructive) {
                    await store.trashSelected()
                }
            case .trash:
                action("복원", systemImage: "arrow.uturn.backward") {
                    await forEachSelected { await store.restore(id: $0) }
                }
                action("영구 삭제", systemImage: "trash.slash", role: .destructive) {
                    await store.deleteSelectedPermanently()
                }
            }
        }
        .padding(.vertical, DropTheme.Spacing.comfortable)
        .frame(maxWidth: .infinity)
        // 목록 위에 잠깐 뜨는 일시적 표면 — 유리가 맞는 자리다 (BRU-75).
        .glassEffect(.regular, in: Rectangle())
        .tint(DropTokens.Colors.accent)
    }

    private func action(
        _ title: String,
        systemImage: String,
        role: ButtonRole? = nil,
        perform: @escaping () async -> Void
    ) -> some View {
        Button(role: role) {
            Task { await perform() }
        } label: {
            Label(title, systemImage: systemImage)
                .labelStyle(.iconOnlyWithCaption)
        }
    }

    /// 선택 목록을 먼저 복사한다 — 처리 중에 store의 선택이 비워지기 때문이다.
    private func forEachSelected(_ body: @escaping (String) async -> Void) async {
        let targets = store.selectedIDs
        store.clearSelection()
        for id in targets {
            await body(id)
        }
    }
}

private struct IconOnlyWithCaption: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(spacing: 2) {
            configuration.icon.font(.title3)
            configuration.title.font(.caption2)
        }
    }
}

private extension LabelStyle where Self == IconOnlyWithCaption {
    static var iconOnlyWithCaption: IconOnlyWithCaption { IconOnlyWithCaption() }
}
