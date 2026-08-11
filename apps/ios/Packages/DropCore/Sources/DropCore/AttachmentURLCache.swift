import Foundation
import Observation

/// 첨부 썸네일에 쓸 서명 URL을 들고 있는다.
///
/// 서명 URL은 발급 비용이 있고 유효기간이 있다. 목록을 스크롤할 때마다 다시 받으면
/// 요청이 폭주하므로, 한 번 받은 것을 만료 전까지 재사용한다.
/// 같은 첨부에 대해 요청이 겹칠 때 두 번 보내지 않도록 진행 중인 작업도 공유한다.
@MainActor
@Observable
public final class AttachmentURLCache {
    private struct Entry {
        let url: URL
        let expiresAt: Date
    }

    private let repository: any AttachmentsRepository
    private let lifetime: TimeInterval
    private var entries: [String: Entry] = [:]
    private var inFlight: [String: Task<URL?, Never>] = [:]

    public init(repository: any AttachmentsRepository, lifetime: TimeInterval = 3600) {
        self.repository = repository
        self.lifetime = lifetime
    }

    public func url(for storagePath: String) async -> URL? {
        if let entry = entries[storagePath], entry.expiresAt > Date() {
            return entry.url
        }
        if let running = inFlight[storagePath] {
            return await running.value
        }

        let task = Task<URL?, Never> { [repository, lifetime] in
            let url = try? await repository.signedURL(for: storagePath, expiresIn: Int(lifetime))
            return url
        }
        inFlight[storagePath] = task
        let url = await task.value
        inFlight[storagePath] = nil

        if let url {
            // 만료 직전에 다시 받도록 조금 일찍 끊는다.
            entries[storagePath] = Entry(url: url, expiresAt: Date().addingTimeInterval(lifetime - 60))
        }
        return url
    }
}
