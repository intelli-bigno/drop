import Foundation
import Testing

@testable import DropCore

/// `whisper_service.dart`의 정책을 그대로 옮겼는지 확인한다.
/// 재시도·크기 제한은 조용히 어긋나면 요금과 사용자 대기 시간으로 돌아온다.
@Suite("Whisper 전사", .serialized)
struct TranscriptionServiceTests {
    private func makeService(
        responder: @escaping @Sendable (URLRequest) -> (Int, Data)
    ) -> (SupabaseTranscriptionService, TranscriptionStubProtocol.Type) {
        TranscriptionStubProtocol.reset()
        TranscriptionStubProtocol.responder = responder

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [TranscriptionStubProtocol.self]

        let service = SupabaseTranscriptionService(
            endpoint: URL(string: "https://stub.supabase.co/functions/v1/transcribe")!,
            authorizationToken: { "token" },
            session: URLSession(configuration: configuration),
            // 테스트에서 실제로 기다리지 않도록 대기를 가로챈다.
            sleep: { _ in }
        )
        return (service, TranscriptionStubProtocol.self)
    }

    private func audioFile(bytes: Int) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString).m4a")
        try Data(repeating: 0, count: bytes).write(to: url)
        return url
    }

    @Test("전사 결과 텍스트를 돌려준다")
    func returnsTranscript() async throws {
        let (service, _) = makeService { _ in (200, Data(#"{"text":"안녕하세요"}"#.utf8)) }

        let text = try await service.transcribe(audioAt: try audioFile(bytes: 100))

        #expect(text == "안녕하세요")
    }

    /// Whisper 업로드 상한은 25MB. 넘으면 **요청을 보내기 전에** 실패해야 한다 —
    /// 올리고 나서 거절당하면 사용자는 그 시간만큼 기다린다.
    @Test("25MB를 넘으면 올리지 않고 실패한다")
    func rejectsOversizedBeforeUpload() async throws {
        let (service, stub) = makeService { _ in (200, Data(#"{"text":""}"#.utf8)) }
        let file = try audioFile(bytes: 25 * 1024 * 1024 + 1)

        await #expect(throws: TranscriptionError.fileTooLarge(25 * 1024 * 1024 + 1)) {
            try await service.transcribe(audioAt: file)
        }
        #expect(stub.requestCount == 0)
    }

    @Test("파일이 없으면 명확히 실패한다")
    func missingFileFails() async {
        let (service, _) = makeService { _ in (200, Data()) }
        let missing = URL(fileURLWithPath: "/없는/경로.m4a")

        await #expect(throws: TranscriptionError.fileNotFound) {
            try await service.transcribe(audioAt: missing)
        }
    }

    /// 429/5xx만 재시도한다. 총 3회 시도 후 포기.
    @Test("속도 제한이면 세 번까지 다시 시도한다")
    func retriesOnRateLimit() async throws {
        let (service, stub) = makeService { _ in (429, Data(#"{"error":"rate limited"}"#.utf8)) }

        await #expect(throws: TranscriptionError.self) {
            try await service.transcribe(audioAt: try audioFile(bytes: 10))
        }
        #expect(stub.requestCount == 3)
    }

    @Test("서버 오류도 재시도 대상이다")
    func retriesOnServerError() async throws {
        let (service, stub) = makeService { _ in (500, Data(#"{"error":"boom"}"#.utf8)) }

        await #expect(throws: TranscriptionError.self) {
            try await service.transcribe(audioAt: try audioFile(bytes: 10))
        }
        #expect(stub.requestCount == 3)
    }

    /// 잘못된 요청은 다시 보내 봐야 같은 답이 온다. 재시도하면 시간만 버린다.
    @Test("400은 재시도하지 않는다")
    func doesNotRetryClientError() async throws {
        let (service, stub) = makeService { _ in (400, Data(#"{"error":"bad"}"#.utf8)) }

        await #expect(throws: TranscriptionError.self) {
            try await service.transcribe(audioAt: try audioFile(bytes: 10))
        }
        #expect(stub.requestCount == 1)
    }

    @Test("재시도 도중 성공하면 그 결과를 쓴다")
    func succeedsOnRetry() async throws {
        let (service, stub) = makeService { _ in
            TranscriptionStubProtocol.requestCount == 1
                ? (503, Data(#"{"error":"busy"}"#.utf8))
                : (200, Data(#"{"text":"두 번째에 성공"}"#.utf8))
        }

        let text = try await service.transcribe(audioAt: try audioFile(bytes: 10))

        #expect(text == "두 번째에 성공")
        #expect(stub.requestCount == 2)
    }

    @Test("multipart 본문과 인증 헤더를 붙여 보낸다")
    func sendsMultipartWithAuthorization() async throws {
        let (service, stub) = makeService { _ in (200, Data(#"{"text":"ok"}"#.utf8)) }

        _ = try await service.transcribe(audioAt: try audioFile(bytes: 10))

        let request = try #require(stub.lastRequest)
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer token")
        #expect(request.value(forHTTPHeaderField: "Content-Type")?.hasPrefix("multipart/form-data") == true)
    }
}

private final class TranscriptionStubProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var responder: (@Sendable (URLRequest) -> (Int, Data))?
    nonisolated(unsafe) private static let lock = NSLock()
    nonisolated(unsafe) private static var _requestCount = 0
    nonisolated(unsafe) private static var _lastRequest: URLRequest?

    static var requestCount: Int {
        lock.lock(); defer { lock.unlock() }
        return _requestCount
    }

    static var lastRequest: URLRequest? {
        lock.lock(); defer { lock.unlock() }
        return _lastRequest
    }

    static func reset() {
        lock.lock(); defer { lock.unlock() }
        _requestCount = 0
        _lastRequest = nil
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.lock.lock()
        Self._requestCount += 1
        // URLSession은 본문을 스트림으로 바꾸므로 헤더만 남겨 확인한다.
        Self._lastRequest = request
        Self.lock.unlock()

        let (status, data) = Self.responder?(request) ?? (500, Data())
        let response = HTTPURLResponse(
            url: request.url!, statusCode: status, httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
