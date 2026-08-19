import DropCore
import DropUI
import SwiftUI

/// `screens/tags_screen.dart` 대응.
/// 태그별 노트 수는 이미 받아 둔 목록에서 세면 되므로 별도 쿼리를 쓰지 않는다.
struct TagsView: View {
    let store: NotesStore

    var body: some View {
        List {
            if tagCounts.isEmpty {
                ContentUnavailableView("태그가 없습니다", systemImage: "number")
            } else {
                ForEach(tagCounts, id: \.tag.id) { entry in
                    Button {
                        store.selectedTagID = entry.tag.id
                    } label: {
                        HStack {
                            Text("#\(entry.tag.name)")
                                .foregroundStyle(DropTokens.Colors.textPrimary)
                            Spacer()
                            Text("\(entry.count)")
                                .foregroundStyle(DropTokens.Colors.textSecondary)
                            if store.selectedTagID == entry.tag.id {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(DropTokens.Colors.accent)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        // 목록은 콘텐츠 레이어 — 종이. 내비게이션 바는 시스템이 유리로 그린다.
        .scrollContentBackground(.hidden)
        .background(DropTheme.Surface.page)
        .navigationTitle("태그")
        .toolbar {
            if store.selectedTagID != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("필터 해제") { store.selectedTagID = nil }
                }
            }
        }
    }

    private var tagCounts: [(tag: Tag, count: Int)] {
        var counts: [String: Int] = [:]
        for note in store.allNotes where note.isActive {
            for tag in note.tags {
                counts[tag.id, default: 0] += 1
            }
        }
        return store.availableTags
            .map { (tag: $0, count: counts[$0.id] ?? 0) }
            .sorted { $0.count > $1.count }
    }
}
