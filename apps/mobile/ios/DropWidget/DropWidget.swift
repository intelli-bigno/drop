import SwiftUI
import WidgetKit

/// 위젯이 그리는 한 시점.
///
/// 무엇을 보여줄지 고르고 자르는 규칙은 전부 앱 쪽(drop_core, Dart)에 있다.
/// 여기서는 이미 정해진 것을 배치만 한다 — 위젯 타깃은 스스로 테스트를 못 돌린다.
struct RecentNotesEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot

    /// 갤러리 미리보기용. 실제 노트를 읽기 전에 보이는 화면이다.
    static let placeholder = RecentNotesEntry(
        date: Date(),
        snapshot: WidgetSnapshot(
            notes: [
                WidgetNote(id: "1", excerpt: "장보기: 우유, 계란", createdAt: Date()),
                WidgetNote(id: "2", excerpt: "회의 전에 지표 확인하기", createdAt: Date().addingTimeInterval(-3600)),
            ],
            generatedAt: Date()
        )
    )
}

struct RecentNotesProvider: TimelineProvider {
    func placeholder(in _: Context) -> RecentNotesEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (RecentNotesEntry) -> Void) {
        completion(context.isPreview ? .placeholder : currentEntry())
    }

    /// 앱이 노트를 불러올 때마다 `WidgetCenter`로 다시 부르므로 자동 갱신 주기는 거들기만 한다.
    func getTimeline(in _: Context, completion: @escaping (Timeline<RecentNotesEntry>) -> Void) {
        let entry = currentEntry()
        completion(Timeline(entries: [entry], policy: .after(entry.date.addingTimeInterval(30 * 60))))
    }

    private func currentEntry() -> RecentNotesEntry {
        RecentNotesEntry(date: Date(), snapshot: WidgetSnapshotStore()?.read() ?? .empty)
    }
}

// MARK: - 최근 노트

struct RecentNotesView: View {
    let entry: RecentNotesEntry
    @Environment(\.widgetFamily) private var family

    private var visibleNotes: [WidgetNote] {
        Array(entry.snapshot.notes.prefix(family == .systemSmall ? 2 : WidgetSnapshot.maximumNoteCount))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            if entry.snapshot.isEmpty {
                emptyState
            } else {
                ForEach(visibleNotes) { note in
                    Link(destination: DropShellLink.noteURL(id: note.id)) {
                        row(note)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var header: some View {
        HStack {
            Text("DROP")
                .font(.caption.weight(.bold))
                .foregroundStyle(DropShellTokens.textSecondary)
            Spacer()
            // 위젯 어디를 눌러도 최소한 작성 화면으로는 가야 한다.
            Link(destination: DropShellLink.quickComposeURL) {
                Image(systemName: "square.and.pencil")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DropShellTokens.accent)
            }
        }
    }

    private func row(_ note: WidgetNote) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(note.excerpt)
                .font(.caption)
                .foregroundStyle(DropShellTokens.textPrimary)
                .lineLimit(family == .systemSmall ? 2 : 1)
                .multilineTextAlignment(.leading)
            Text(RelativeTimeFormatter().string(for: note.createdAt))
                .font(.caption2)
                .foregroundStyle(DropShellTokens.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("아직 노트가 없습니다")
                .font(.caption)
                .foregroundStyle(DropShellTokens.textSecondary)
            Text("눌러서 첫 노트 쓰기")
                .font(.caption2)
                .foregroundStyle(DropShellTokens.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct RecentNotesWidget: Widget {
    let kind = "RecentNotesWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: RecentNotesProvider()) { entry in
            RecentNotesView(entry: entry)
                // 홈 화면 위젯도 앱과 같은 웜 페이퍼를 쓴다 (BRU-75).
                // 시스템 기본 채움을 두면 위젯만 회색으로 떠 다른 앱처럼 보인다.
                .containerBackground(DropShellTokens.cardBackground, for: .widget)
                // 노트 줄을 벗어난 곳을 눌렀을 때의 기본 행선지.
                .widgetURL(DropShellLink.quickComposeURL)
        }
        .configurationDisplayName("최근 노트")
        .description("최근에 적은 노트를 보고, 눌러서 바로 씁니다.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - 빠른 작성

struct QuickComposeView: View {
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: "square.and.pencil").font(.title3)
            }
        default:
            VStack(spacing: 6) {
                Image(systemName: "square.and.pencil")
                    .font(.largeTitle)
                    .foregroundStyle(DropShellTokens.accent)
                Text("새 노트")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DropShellTokens.textSecondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

struct QuickComposeWidget: Widget {
    let kind = "QuickComposeWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: RecentNotesProvider()) { _ in
            QuickComposeView()
                .containerBackground(DropShellTokens.cardBackground, for: .widget)
                .widgetURL(DropShellLink.quickComposeURL)
        }
        .configurationDisplayName("새 노트")
        .description("바로 작성 화면을 엽니다.")
        .supportedFamilies([.systemSmall, .accessoryCircular])
    }
}

// MARK: - 사진 바로가기 (BRU-43)

/// 카메라·갤러리 위젯은 아이콘과 행선지만 다르다. 두 벌로 베껴 두면
/// 한쪽만 고쳐지는 자리가 생긴다.
struct ShortcutView: View {
    let systemImage: String
    let title: String

    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: systemImage).font(.title3)
            }
        default:
            VStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.largeTitle)
                    .foregroundStyle(DropShellTokens.accent)
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DropShellTokens.textSecondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

struct CameraWidget: Widget {
    let kind = "CameraWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: RecentNotesProvider()) { _ in
            ShortcutView(systemImage: "camera", title: "사진 찍기")
                .containerBackground(DropShellTokens.cardBackground, for: .widget)
                .widgetURL(DropShellLink.cameraURL)
        }
        .configurationDisplayName("사진 찍기")
        .description("카메라를 열어 찍은 사진을 바로 노트로 만듭니다.")
        .supportedFamilies([.systemSmall, .accessoryCircular])
    }
}

struct GalleryWidget: Widget {
    let kind = "GalleryWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: RecentNotesProvider()) { _ in
            ShortcutView(systemImage: "photo.on.rectangle", title: "사진 고르기")
                .containerBackground(DropShellTokens.cardBackground, for: .widget)
                .widgetURL(DropShellLink.galleryURL)
        }
        .configurationDisplayName("사진 고르기")
        .description("사진 보관함을 열어 고른 사진을 바로 노트로 만듭니다.")
        .supportedFamilies([.systemSmall, .accessoryCircular])
    }
}
