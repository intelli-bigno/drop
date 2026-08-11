import Foundation

/// Share Extension이 앱에 넘기는 한 건.
public struct SharedItem: Codable, Equatable, Sendable {
    public let text: String
    /// App Group 컨테이너에 함께 저장한 파일 이름들.
    public let fileNames: [String]
    public let createdAt: Date

    public init(text: String, fileNames: [String], createdAt: Date = Date()) {
        self.text = text
        self.fileNames = fileNames
        self.createdAt = createdAt
    }
}

/// 확장과 앱이 App Group 컨테이너를 통해 주고받는 수신함.
///
/// 확장에서 곧바로 Supabase에 쓰지 않는 이유는 둘이다:
/// 확장은 메모리 한도(약 120MB)가 좁고, 세션이 없을 수도 있다.
/// 그래서 **적어 두기만** 하고 앱이 켜질 때 비운다.
public struct SharedInbox: Sendable {
    public static let appGroupID = "group.com.intellieffect.drop"

    private let containerURL: URL

    public init(containerURL: URL) {
        self.containerURL = containerURL
    }

    /// App Group이 설정돼 있지 않으면 nil — 이 경우 공유 기능만 동작하지 않고
    /// 앱의 나머지는 그대로 돌아간다.
    public init?(appGroupID: String = SharedInbox.appGroupID) {
        guard let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else {
            return nil
        }
        self.init(containerURL: url.appendingPathComponent("inbox", isDirectory: true))
    }

    public func enqueue(_ item: SharedItem) throws {
        try FileManager.default.createDirectory(at: containerURL, withIntermediateDirectories: true)
        let name = "item-\(item.createdAt.timeIntervalSince1970)-\(UUID().uuidString).json"
        try DropJSON.encoder.encode(item).write(to: containerURL.appendingPathComponent(name))
    }

    /// 파일을 저장할 위치(확장이 이미지·동영상을 복사해 두는 곳).
    public func fileURL(named name: String) -> URL {
        containerURL.appendingPathComponent("files", isDirectory: true).appendingPathComponent(name)
    }

    public func prepareFilesDirectory() throws {
        try FileManager.default.createDirectory(
            at: containerURL.appendingPathComponent("files", isDirectory: true),
            withIntermediateDirectories: true
        )
    }

    /// 쌓인 항목을 모두 꺼내고 비운다.
    ///
    /// 꺼낸 항목은 반드시 지운다 — 남기면 앱을 켤 때마다 같은 노트가 다시 만들어진다.
    /// 깨진 파일 하나가 나머지를 막지 않도록, 읽기에 실패한 것도 함께 치운다.
    public func drain() throws -> [SharedItem] {
        let manager = FileManager.default
        guard manager.fileExists(atPath: containerURL.path) else { return [] }

        let files = try manager.contentsOfDirectory(at: containerURL, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }

        var items: [SharedItem] = []
        for file in files {
            if let data = try? Data(contentsOf: file),
               let item = try? DropJSON.decoder.decode(SharedItem.self, from: data)
            {
                items.append(item)
            }
            try? manager.removeItem(at: file)
        }
        return items
    }
}
