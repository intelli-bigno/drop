import Foundation
import Testing

@testable import DropCore

/// Share Extension은 앱이 실행 중이 아닐 수도 있고, 메모리 한도(약 120MB)도 좁다.
/// 그래서 확장은 App Group 컨테이너에 **적어 두기만** 하고, 앱이 켜질 때 비운다.
@Suite("공유 수신함")
struct SharedInboxTests {
    private func makeInbox() throws -> (SharedInbox, URL) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return (SharedInbox(containerURL: directory), directory)
    }

    @Test("적어 둔 항목을 순서대로 꺼낸다")
    func drainsInOrder() throws {
        let (inbox, _) = try makeInbox()

        try inbox.enqueue(SharedItem(text: "첫 번째", fileNames: []))
        try inbox.enqueue(SharedItem(text: "두 번째", fileNames: []))

        #expect(try inbox.drain().map(\.text) == ["첫 번째", "두 번째"])
    }

    /// 두 번 처리하면 노트가 두 개 생긴다. 꺼낸 항목은 반드시 지워져야 한다.
    @Test("한 번 꺼내면 비워진다")
    func drainRemovesItems() throws {
        let (inbox, _) = try makeInbox()
        try inbox.enqueue(SharedItem(text: "한 번만", fileNames: []))

        _ = try inbox.drain()

        #expect(try inbox.drain().isEmpty)
    }

    @Test("빈 수신함을 꺼내도 오류가 아니다")
    func emptyDrainIsFine() throws {
        let (inbox, _) = try makeInbox()
        #expect(try inbox.drain().isEmpty)
    }

    /// 확장이 죽으면서 반쯤 쓴 파일이 남을 수 있다. 그것 하나가 전체 처리를 막으면 안 된다.
    @Test("깨진 항목은 건너뛰고 나머지를 처리한다")
    func skipsCorruptItems() throws {
        let (inbox, directory) = try makeInbox()
        try inbox.enqueue(SharedItem(text: "정상", fileNames: []))
        try Data("망가진 내용".utf8)
            .write(to: directory.appendingPathComponent("item-broken.json"))

        let items = try inbox.drain()

        #expect(items.map(\.text) == ["정상"])
        // 깨진 파일도 함께 치운다 — 남겨 두면 매번 실패를 반복한다.
        #expect(try inbox.drain().isEmpty)
    }

    @Test("첨부 파일 이름을 함께 실어 나른다")
    func carriesFileNames() throws {
        let (inbox, _) = try makeInbox()
        try inbox.enqueue(SharedItem(text: "사진", fileNames: ["a.jpg", "b.jpg"]))

        #expect(try inbox.drain().first?.fileNames == ["a.jpg", "b.jpg"])
    }
}

@Suite("딥링크 해석")
struct DropLinkTests {
    @Test("노트 상세 링크를 읽는다")
    func parsesNoteLink() {
        #expect(DropLink(url: URL(string: "drop://note/abc-123")!) == .note(id: "abc-123"))
    }

    @Test("웹 링크도 같은 경로로 읽는다")
    func parsesUniversalLink() {
        #expect(DropLink(url: URL(string: "https://drop.intellieffect.com/note/xyz")!) == .note(id: "xyz"))
    }

    @Test("새 노트 작성 링크를 읽는다")
    func parsesComposeLink() {
        #expect(DropLink(url: URL(string: "drop://compose?text=%EB%A9%94%EB%AA%A8")!) == .compose(text: "메모"))
    }

    @Test("본문 없는 작성 링크도 유효하다")
    func parsesComposeWithoutText() {
        #expect(DropLink(url: URL(string: "drop://compose")!) == .compose(text: nil))
    }

    /// Google 로그인 콜백이 같은 경로로 들어온다. 여기서 삼키면 로그인이 끊긴다.
    @Test("모르는 링크는 nil이다")
    func unknownLinkIsNil() {
        #expect(DropLink(url: URL(string: "com.googleusercontent.apps.123:/oauth2redirect")!) == nil)
        #expect(DropLink(url: URL(string: "drop://알수없음")!) == nil)
    }

    @Test("빈 노트 id는 받아들이지 않는다")
    func emptyNoteIDIsNil() {
        #expect(DropLink(url: URL(string: "drop://note/")!) == nil)
    }

    @Test("카메라 링크를 읽는다")
    func parsesCameraLink() {
        #expect(DropLink(url: URL(string: "drop://camera")!) == .camera)
    }

    @Test("갤러리 링크를 읽는다")
    func parsesGalleryLink() {
        #expect(DropLink(url: URL(string: "drop://gallery")!) == .gallery)
    }

    /// 웹 링크로도 같은 곳으로 가야 한다 — 링크 해석 경로는 하나다.
    @Test("웹 링크로도 카메라·갤러리를 연다")
    func parsesUniversalCameraAndGalleryLinks() {
        #expect(DropLink(url: URL(string: "https://drop.intellieffect.com/camera")!) == .camera)
        #expect(DropLink(url: URL(string: "https://drop.intellieffect.com/gallery")!) == .gallery)
    }

    /// 녹음 기능은 BRU-48에서 앱에서 제거됐다. 없는 곳으로 보내는 링크를 만들지 않는다.
    @Test("녹음 링크는 여전히 모르는 링크다")
    func recordLinkStaysUnknown() {
        #expect(DropLink(url: URL(string: "drop://record")!) == nil)
    }
}
