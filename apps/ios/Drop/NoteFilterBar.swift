import DropCore
import DropUI
import SwiftUI

/// `widgets/category_filter.dart` + `view_mode_selector.dart` 대응.
///
/// **한 줄만 쓴다.** 예전에는 검색 캡슐 · 보기 세그먼트 · 카테고리 칩이 각각
/// 한 줄씩 세 줄을 먹어 목록이 화면 절반으로 줄어 있었다(BRU-49).
/// 보기 전환(노트/보관/휴지통)은 자주 쓰지 않으므로 상단 `⋯` 메뉴로 옮겼고,
/// 검색은 아이콘으로 접어 두었다가 누를 때만 펼친다.
struct NoteFilterBar: View {
    @Bindable var store: NotesStore

    @State private var isSearching = false
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        HStack(spacing: DropTheme.Spacing.base) {
            Button {
                toggleSearch()
            } label: {
                Image(systemName: isSearching ? "xmark" : "magnifyingglass")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(isSearching ? Color.accentColor : Color.secondary)
                    .frame(width: 32, height: 32)
                    .background(Color.secondary.opacity(0.10), in: Circle())
            }
            .buttonStyle(.plain)

            if isSearching {
                // 검색은 여기 둔다. `.searchable`은 iOS 26에서 화면 하단에 붙어
                // 액션 버튼과 겹친다.
                TextField("노트 검색", text: $store.searchText)
                    .textFieldStyle(.plain)
                    .font(.subheadline)
                    .autocorrectionDisabled()
                    .focused($isSearchFocused)
                    .submitLabel(.search)
                    .padding(.horizontal, DropTheme.Spacing.comfortable)
                    .padding(.vertical, 6)
                    .background(Color.secondary.opacity(0.12), in: Capsule())
            } else {
                chips
            }
        }
        .padding(.horizontal, DropTheme.Spacing.comfortable)
        .padding(.vertical, DropTheme.Spacing.base)
    }

    private var chips: some View {
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
        }
    }

    /// 접을 때 질의를 비운다 — 보이지 않는 검색어가 목록을 계속 거르면
    /// 노트가 사라진 것처럼 보인다.
    private func toggleSearch() {
        isSearching.toggle()
        if isSearching {
            isSearchFocused = true
        } else {
            store.searchText = ""
        }
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
