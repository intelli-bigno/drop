import Foundation

public enum TranscriptionError: Error, Equatable {
    case fileNotFound
    case fileTooLarge(Int)
    case rateLimited
    case serverError(Int)
    case rejected(Int)
    case network(String)
    case malformedResponse
}

public protocol TranscriptionService: Sendable {
    func transcribe(audioAt url: URL, language: String?) async throws -> String
}

public extension TranscriptionService {
    func transcribe(audioAt url: URL) async throws -> String {
        try await transcribe(audioAt: url, language: nil)
    }
}

/// `whisper_service.dart`를 옮긴 것. 정책은 그대로 둔다:
/// 25MB 상한 · 3회 시도 · 429/5xx만 지수 백오프(1s, 2s) · 마지막 시도 뒤에는 기다리지 않는다.
public struct SupabaseTranscriptionService: TranscriptionService {
    public static let maxFileSizeBytes = 25 * 1024 * 1024
    private static let attemptLimit = 3

    private let endpoint: URL
    private let authorizationToken: @Sendable () -> String?
    private let session: URLSession
    private let sleep: @Sendable (Duration) async -> Void

    public init(
        endpoint: URL,
        authorizationToken: @escaping @Sendable () -> String?,
        session: URLSession = {
            let configuration = URLSessionConfiguration.default
            configuration.timeoutIntervalForRequest = 15
            configuration.timeoutIntervalForResource = 120
            return URLSession(configuration: configuration)
        }(),
        sleep: @escaping @Sendable (Duration) async -> Void = { try? await Task.sleep(for: $0) }
    ) {
        self.endpoint = endpoint
        self.authorizationToken = authorizationToken
        self.session = session
        self.sleep = sleep
    }

    public func transcribe(audioAt url: URL, language: String?) async throws -> String {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw TranscriptionError.fileNotFound
        }

        let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0
        // 올리고 나서 거절당하면 사용자는 그 업로드 시간만큼 헛되이 기다린다.
        guard size <= Self.maxFileSizeBytes else {
            throw TranscriptionError.fileTooLarge(size)
        }

        let data = try Data(contentsOf: url)
        var lastError: TranscriptionError = .network("시도하지 못했습니다")

        for attempt in 0..<Self.attemptLimit {
            do {
                return try await send(data: data, fileName: url.lastPathComponent, language: language)
            } catch let error as TranscriptionError {
                guard Self.isRetryable(error) else { throw error }
                lastError = error
                // 마지막 시도 뒤에는 기다리지 않는다 — 기다려도 할 일이 없다.
                if attempt < Self.attemptLimit - 1 {
                    await sleep(.seconds(1 << attempt))
                }
            }
        }
        throw lastError
    }

    private static func isRetryable(_ error: TranscriptionError) -> Bool {
        switch error {
        case .rateLimited, .serverError, .network: true
        default: false
        }
    }

    private func send(data: Data, fileName: String, language: String?) async throws -> String {
        let boundary = "drop-\(UUID().uuidString)"
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        if let token = authorizationToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = Self.multipartBody(
            boundary: boundary, data: data, fileName: fileName, language: language
        )

        let (responseData, response): (Data, URLResponse)
        do {
            (responseData, response) = try await session.data(for: request)
        } catch {
            throw TranscriptionError.network(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw TranscriptionError.malformedResponse
        }

        switch http.statusCode {
        case 200..<300:
            guard
                let json = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
                let text = json["text"] as? String
            else {
                throw TranscriptionError.malformedResponse
            }
            return text
        case 429:
            throw TranscriptionError.rateLimited
        case 500...:
            throw TranscriptionError.serverError(http.statusCode)
        default:
            throw TranscriptionError.rejected(http.statusCode)
        }
    }

    private static func multipartBody(
        boundary: String, data: Data, fileName: String, language: String?
    ) -> Data {
        var body = Data()
        func append(_ string: String) { body.append(Data(string.utf8)) }

        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n")
        append("Content-Type: audio/m4a\r\n\r\n")
        body.append(data)
        append("\r\n")

        if let language {
            append("--\(boundary)\r\n")
            append("Content-Disposition: form-data; name=\"language\"\r\n\r\n")
            append("\(language)\r\n")
        }

        append("--\(boundary)--\r\n")
        return body
    }
}
