import Foundation

/// 확장이 앱(Flutter/drop_core)과 주고받는 파일 계약 — `apps/ios/Packages/DropCore`의
/// `SharedInbox.swift`·`WidgetSnapshot.swift`·`DropJSON.swift`에서 필요한 만큼만 옮겼다.
///
/// Dart 짝은 `packages/drop_core/lib/src/shared_inbox.dart`·`widget_snapshot.dart`.
/// 키(snake_case)와 시각 표기(ISO8601, 분수초 허용)가 이쪽 계약이다.

enum DropShellJSON {
    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom { decoder in
            let raw = try decoder.singleValueContainer().decode(String.self)
            guard let date = timestamp(from: raw) else {
                throw DecodingError.dataCorrupted(
                    .init(codingPath: decoder.codingPath, debugDescription: "시각 형식을 알 수 없습니다: \(raw)")
                )
            }
            return date
        }
        return decoder
    }()

    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(fractional.string(from: date))
        }
        return encoder
    }()

    private static let fractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let plain: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static func timestamp(from raw: String) -> Date? {
        fractional.date(from: raw) ?? plain.date(from: raw)
    }
}

/// Share Extension이 앱에 넘기는 한 건.
struct SharedItem: Codable {
    let text: String
    /// App Group 컨테이너에 함께 저장한 파일 이름들.
    let fileNames: [String]
    let createdAt: Date

    init(text: String, fileNames: [String], createdAt: Date = Date()) {
        self.text = text
        self.fileNames = fileNames
        self.createdAt = createdAt
    }
}

/// 확장과 앱이 App Group 컨테이너를 통해 주고받는 수신함 — **적는 쪽**.
/// 비우는 쪽은 앱(drop_core `SharedInbox.drain`)이다.
struct SharedInbox {
    /// Flutter 앱이 이미 쓰고 있는 그룹이다. 새로 만들면 App Group 연결에
    /// 포털 수작업이 필요해진다(공개 API에 App Group 엔드포인트가 없다).
    static let appGroupID = "group.com.intellieffect.drop.shared"

    private let containerURL: URL

    init?(appGroupID: String = SharedInbox.appGroupID) {
        guard let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else {
            return nil
        }
        containerURL = url.appendingPathComponent("inbox", isDirectory: true)
    }

    func enqueue(_ item: SharedItem) throws {
        try FileManager.default.createDirectory(at: containerURL, withIntermediateDirectories: true)
        let name = "item-\(item.createdAt.timeIntervalSince1970)-\(UUID().uuidString).json"
        try DropShellJSON.encoder.encode(item).write(to: containerURL.appendingPathComponent(name))
    }

    /// 파일을 저장할 위치(확장이 이미지·동영상을 복사해 두는 곳).
    func fileURL(named name: String) -> URL {
        containerURL.appendingPathComponent("files", isDirectory: true).appendingPathComponent(name)
    }

    func prepareFilesDirectory() throws {
        try FileManager.default.createDirectory(
            at: containerURL.appendingPathComponent("files", isDirectory: true),
            withIntermediateDirectories: true
        )
    }
}

/// 위젯 한 줄에 들어가는 노트. 발췌는 앱이 이미 접고 잘라 둔 상태다.
struct WidgetNote: Codable, Identifiable {
    let id: String
    let excerpt: String
    let createdAt: Date
}

/// 앱이 위젯에게 넘기는 요약 한 벌. 만드는 규칙은 drop_core(Dart)에 있고
/// 테스트가 덮는다 — 위젯은 이미 정해진 것을 배치만 한다.
struct WidgetSnapshot: Codable {
    static let maximumNoteCount = 3

    static let empty = WidgetSnapshot(notes: [], generatedAt: .distantPast)

    let notes: [WidgetNote]
    let generatedAt: Date

    var isEmpty: Bool { notes.isEmpty }
}

/// 스냅샷이 오가는 App Group 파일 하나 — **읽는 쪽**. 적는 쪽은 앱(drop_core)이다.
struct WidgetSnapshotStore {
    static let appGroupID = SharedInbox.appGroupID

    let fileURL: URL

    init?(appGroupID: String = WidgetSnapshotStore.appGroupID) {
        guard let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else {
            return nil
        }
        fileURL = url.appendingPathComponent("widget-snapshot.json")
    }

    /// 읽기는 실패하지 않는다. 파일이 없든 깨졌든 위젯은 빈 상태로라도 그려져야 한다.
    func read() -> WidgetSnapshot {
        guard let data = try? Data(contentsOf: fileURL),
              let snapshot = try? DropShellJSON.decoder.decode(WidgetSnapshot.self, from: data)
        else {
            return .empty
        }
        return snapshot
    }
}

/// 위젯이 여는 링크. 해석은 앱(drop_core `DropLink`)이 한다 — URL 문자열이 계약이다.
enum DropShellLink {
    static let quickComposeURL = URL(string: "drop://compose")!
    static let cameraURL = URL(string: "drop://camera")!
    static let galleryURL = URL(string: "drop://gallery")!

    static func noteURL(id: String) -> URL {
        URL(string: "drop://note/\(id)") ?? quickComposeURL
    }
}

/// 노트 목록에 붙는 상대 시간 문구 — DropCore `RelativeTimeFormatter.swift` 그대로.
struct RelativeTimeFormatter {
    private let calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    func string(for date: Date, now: Date = Date()) -> String {
        let elapsed = max(0, now.timeIntervalSince(date))

        let seconds = Int(elapsed)
        if seconds < 60 { return "\(seconds)초전" }

        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes)분전" }

        let day = calendar.startOfDay(for: date)
        let today = calendar.startOfDay(for: now)

        if day == today { return "오늘 \(clockTime(of: date))" }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: today), day == yesterday {
            return "어제 \(clockTime(of: date))"
        }

        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return "\(parts.year!). \(parts.month!). \(parts.day!)."
    }

    private func clockTime(of date: Date) -> String {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", parts.hour!, parts.minute!)
    }
}
