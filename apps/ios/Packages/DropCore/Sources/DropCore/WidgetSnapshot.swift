import Foundation

/// 위젯 한 줄에 들어가는 노트.
///
/// `Note`를 그대로 싣지 않는 이유는 둘이다: 첨부·태그까지 App Group 파일에 복사할 이유가 없고,
/// 필드가 바뀔 때마다 위젯이 못 읽는 옛 파일을 만들게 된다. 위젯이 실제로 그리는 것만 담는다.
public struct WidgetNote: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    /// 이미 한 줄로 접히고 잘린 상태. 위젯 쪽에서 더 손대지 않는다.
    public let excerpt: String
    public let createdAt: Date

    public init(id: String, excerpt: String, createdAt: Date) {
        self.id = id
        self.excerpt = excerpt
        self.createdAt = createdAt
    }
}

/// 앱이 위젯에게 넘기는 요약 한 벌.
///
/// 위젯 확장은 Supabase에 접속하지 않는다 — 세션이 없을 수도 있고 메모리 한도도 좁다.
/// 앱이 노트를 불러올 때마다 이 스냅샷을 App Group에 적어 두고, 위젯은 그것만 읽는다.
public struct WidgetSnapshot: Codable, Equatable, Sendable {
    /// 작은 위젯에 실제로 보이는 줄 수.
    public static let maximumNoteCount = 3
    /// 말줄임표를 포함한 발췌 최대 길이.
    public static let excerptLimit = 80
    /// 본문이 빈 노트(사진만 붙인 노트 등)를 대신하는 문구.
    public static let emptyContentPlaceholder = "(내용 없음)"

    /// 앱이 아직 한 번도 쓰지 않았거나 파일이 깨졌을 때의 값.
    public static let empty = WidgetSnapshot(notes: [], generatedAt: .distantPast)

    public let notes: [WidgetNote]
    public let generatedAt: Date

    public init(notes: [WidgetNote], generatedAt: Date) {
        self.notes = notes
        self.generatedAt = generatedAt
    }

    /// 앱이 들고 있는 노트 목록에서 위젯용 요약을 만든다.
    public init(from notes: [Note], generatedAt: Date = Date()) {
        self.init(
            notes: notes
                .filter(\.isActive)
                .sorted { $0.createdAt > $1.createdAt }
                .prefix(Self.maximumNoteCount)
                .map { note in
                    WidgetNote(
                        id: note.id,
                        excerpt: Self.excerpt(from: note.content),
                        createdAt: note.createdAt
                    )
                },
            generatedAt: generatedAt
        )
    }

    public var isEmpty: Bool { notes.isEmpty }

    /// 본문을 위젯 한 줄에 맞게 접고 자른다.
    static func excerpt(from content: String) -> String {
        let flattened = content
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")

        if flattened.isEmpty { return emptyContentPlaceholder }
        guard flattened.count > excerptLimit else { return flattened }
        return flattened.prefix(excerptLimit - 1) + "…"
    }
}

/// 스냅샷이 오가는 App Group 파일 하나.
public struct WidgetSnapshotStore: Sendable {
    /// 공유 수신함과 같은 그룹을 쓴다 — 새 그룹은 포털 수작업을 부른다(공개 API에 App Group 엔드포인트가 없다).
    public static let appGroupID = SharedInbox.appGroupID

    public let fileURL: URL

    public init(containerURL: URL) {
        fileURL = containerURL.appendingPathComponent("widget-snapshot.json")
    }

    /// App Group이 설정돼 있지 않으면 nil — 이 경우 위젯만 비고 앱의 나머지는 그대로 돌아간다.
    public init?(appGroupID: String = WidgetSnapshotStore.appGroupID) {
        guard let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else {
            return nil
        }
        self.init(containerURL: url)
    }

    public func write(_ snapshot: WidgetSnapshot) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try DropJSON.encoder.encode(snapshot).write(to: fileURL, options: .atomic)
    }

    /// 읽기는 실패하지 않는다. 파일이 없든 깨졌든 위젯은 빈 상태로라도 그려져야 한다.
    public func read() -> WidgetSnapshot {
        guard let data = try? Data(contentsOf: fileURL),
              let snapshot = try? DropJSON.decoder.decode(WidgetSnapshot.self, from: data)
        else {
            return .empty
        }
        return snapshot
    }
}
