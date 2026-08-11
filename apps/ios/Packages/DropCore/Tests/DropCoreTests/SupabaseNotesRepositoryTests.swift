import Foundation
import Supabase
import Testing

@testable import DropCore

/// 실제 네트워크 없이 Supabase 클라이언트를 태워 본다.
/// URLProtocol 스텁으로 응답을 만들어, **우리 디코더가 실제 경로에 물려 있는지**를 확인한다.
/// (SDK 기본 디코더를 그대로 두면 snake_case와 분수초 timestamptz에서 조용히 깨진다.)
@Suite("Supabase 노트 리포지토리", .serialized)
struct SupabaseNotesRepositoryTests {
    private func makeRepository(
        responder: @escaping @Sendable (URLRequest) -> (Int, Data)
    ) -> SupabaseNotesRepository {
        StubURLProtocol.responder = responder

        let sessionConfiguration = URLSessionConfiguration.ephemeral
        sessionConfiguration.protocolClasses = [StubURLProtocol.self]

        let client = SupabaseClient(
            supabaseURL: URL(string: "https://stub.supabase.co")!,
            supabaseKey: "anon",
            options: SupabaseClientOptions(
                db: SupabaseClientOptions.DatabaseOptions(
                    encoder: DropJSON.encoder,
                    decoder: DropJSON.decoder
                ),
                global: SupabaseClientOptions.GlobalOptions(
                    session: URLSession(configuration: sessionConfiguration)
                )
            )
        )
        return SupabaseNotesRepository(client: client)
    }

    @Test("목록 응답을 모델로 읽는다")
    func decodesListResponse() async throws {
        let repository = makeRepository { request in
            let path = request.url?.path ?? ""
            if path.hasSuffix("/notes") {
                return (200, Data("""
                [{"id":"n1","display_id":3,"content":"본문","created_at":"2026-08-11T09:30:00.123456+00:00",
                  "updated_at":"2026-08-11T09:30:00+00:00","source":"mobile","is_pinned":false}]
                """.utf8))
            }
            if path.hasSuffix("/attachments") {
                return (200, Data("""
                [{"id":"a1","note_id":"n1","type":"image","storage_path":"p/a1",
                  "created_at":"2026-08-11T09:30:00+00:00"}]
                """.utf8))
            }
            return (200, Data("""
            [{"note_id":"n1","tags":{"id":"t1","name":"일","created_at":"2026-08-01T00:00:00+00:00"}}]
            """.utf8))
        }

        let notes = try await repository.loadNotes()

        #expect(notes.count == 1)
        #expect(notes[0].displayID == 3)
        #expect(notes[0].attachments.map(\.id) == ["a1"])
        #expect(notes[0].tags.map(\.name) == ["일"])
    }

    /// 노트가 없으면 첨부·태그 쿼리를 아예 보내지 않아야 한다.
    /// 빈 `in` 필터는 PostgREST에서 오류이거나 전체 조회가 되어버린다.
    @Test("노트가 없으면 뒤따르는 쿼리를 보내지 않는다")
    func skipsRelationQueriesWhenEmpty() async throws {
        let counter = RequestCounter()
        let repository = makeRepository { request in
            counter.record(request.url?.path ?? "")
            return (200, Data("[]".utf8))
        }

        let notes = try await repository.loadNotes()

        #expect(notes.isEmpty)
        #expect(counter.paths.filter { $0.hasSuffix("/attachments") }.isEmpty)
    }

    @Test("서버 거절은 rejected 오류로 좁힌다")
    func mapsServerRejection() async {
        let repository = makeRepository { _ in
            (403, Data(#"{"message":"권한이 없습니다","code":"42501"}"#.utf8))
        }

        await #expect(throws: NotesRepositoryError.self) {
            try await repository.loadNotes()
        }
    }
}

private final class RequestCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [String] = []

    var paths: [String] {
        lock.lock(); defer { lock.unlock() }
        return storage
    }

    func record(_ path: String) {
        lock.lock(); defer { lock.unlock() }
        storage.append(path)
    }
}

private final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var responder: (@Sendable (URLRequest) -> (Int, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let (status, data) = Self.responder?(request) ?? (500, Data())
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: status,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
