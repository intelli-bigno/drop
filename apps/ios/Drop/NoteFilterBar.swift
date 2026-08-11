import DropCore
import DropUI
import SwiftUI

/// `widgets/category_filter.dart` + `view_mode_selector.dart` 대응.
struct NoteFilterBar: View {
    @Bindable var store: NotesStore

    var body: some View {
        VStack(spacing: DropTheme.Spacing.base) {
            // 검색은 여기 둔다. `.searchable`은 iOS 26에서 화면 하단에 붙어
            // 액션 버튼과 겹친다.
            HStack(spacing: DropTheme.Spacing.base) {
                Image(systemName: "magnifyingglass")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                TextField("노트 검색", text: $store.searchText)
                    .textFieldStyle(.plain)
                    .autocorrectionDisabled()
                if !store.searchText.isEmpty {
                    Button {
                        store.searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, DropTheme.Spacing.comfortable)
            .padding(.vertical, DropTheme.Spacing.base)
            .background(Color.secondary.opacity(0.12), in: Capsule())
            .padding(.horizontal, DropTheme.Spacing.comfortable)

            Picker("보기", selection: $store.viewMode) {
                Text("노트").tag(NoteViewMode.active)
                Text("보관").tag(NoteViewMode.archived)
                Text("휴지통").tag(NoteViewMode.trash)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, DropTheme.Spacing.comfortable)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DropTheme.Spacing.base) {
                    ForEach(NoteCategory.allCases, id: \.self) { category in
                        FilterChip(
                            title: label(for: category),
                            isOn: store.category == category
                        ) {
                            store.category = category
                        }
                    }

                    if !store.availableTags.isEmpty {
                        Divider().frame(height: 20)
                    }

                    ForEach(store.availableTags) { tag in
                        FilterChip(
                            title: "#\(tag.name)",
                            isOn: store.selectedTagID == tag.id
                        ) {
                            // 같은 태그를 다시 누르면 필터를 푼다.
                            store.selectedTagID = store.selectedTagID == tag.id ? nil : tag.id
                        }
                    }
                }
                .padding(.horizontal, DropTheme.Spacing.comfortable)
            }
        }
        .padding(.vertical, DropTheme.Spacing.base)
    }

    private func label(for category: NoteCategory) -> String {
        switch category {
        case .all: "전체"
        case .links: "링크"
        case .media: "미디어"
        case .files: "파일"
        }
    }
}

struct FilterChip: View {
    let title: String
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.footnote.weight(isOn ? .semibold : .regular))
                .padding(.horizontal, DropTheme.Spacing.comfortable)
                .padding(.vertical, DropTheme.Spacing.base)
                .background(
                    isOn ? Color.accentColor.opacity(0.18) : Color.secondary.opacity(0.10),
                    in: Capsule()
                )
                .foregroundStyle(isOn ? Color.accentColor : Color.primary)
        }
        .buttonStyle(.plain)
    }
}
