import Foundation
import Testing

@testable import DropCore

/// 위젯은 Supabase에 접속하지 않는다 — 세션도 없고 메모리 한도도 좁다.
/// 앱이 App Group에 **적어 둔 요약**만 읽어 그린다. 그 요약을 만드는 규칙이 여기 있다.
@Suite("위젯 스냅샷 만들기")
struct WidgetSnapshotBuildTests {
    private func note(
        id: String,
        content: String,
        createdAt: Date,
        archivedAt: Date? = nil,
        deletedAt: Date? = nil
    ) -> Note {
        Note(
            id: id,
            displayID: 1,
            content: content,
            createdAt: createdAt,
            updatedAt: createdAt,
            source: .mobile,
            archivedAt: archivedAt,
            deletedAt: deletedAt
        )
    }

    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    @Test("최신 노트를 앞에 둔다")
    func newestFirst() {
        let snapshot = WidgetSnapshot(
            from: [
                note(id: "오래된", content: "오래된", createdAt: now.addingTimeInterval(-600)),
                note(id: "최신", content: "최신", createdAt: now),
            ],
            generatedAt: now
        )

        #expect(snapshot.notes.map(\.id) == ["최신", "오래된"])
    }

    /// 위젯 크기가 작아 더 실어도 보이지 않는다. 보관·휴지통은 애초에 "최근"이 아니다.
    @Test("활성 노트만, 최대 개수까지만 싣는다")
    func keepsOnlyActiveNotesUpToLimit() {
        let snapshot = WidgetSnapshot(
            from: [
                note(id: "1", content: "하나", createdAt: now),
                note(id: "2", content: "둘", createdAt: now.addingTimeInterval(-1)),
                note(id: "3", content: "셋", createdAt: now.addingTimeInterval(-2)),
                note(id: "4", content: "넷", createdAt: now.addingTimeInterval(-3)),
                note(id: "보관", content: "보관", createdAt: now, archivedAt: now),
                note(id: "휴지통", content: "휴지통", createdAt: now, deletedAt: now),
            ],
            generatedAt: now
        )

        #expect(snapshot.notes.count == WidgetSnapshot.maximumNoteCount)
        #expect(snapshot.notes.map(\.id) == ["1", "2", "3"])
    }

    /// 위젯은 한 줄씩 보여준다 — 줄바꿈이 그대로 들어오면 첫 줄만 보이고 나머지가 잘린다.
    @Test("여러 줄 본문을 한 줄로 접는다")
    func flattensWhitespace() {
        let snapshot = WidgetSnapshot(
            from: [note(id: "1", content: "  첫 줄\n\n 둘째   줄  ", createdAt: now)],
            generatedAt: now
        )

        #expect(snapshot.notes.first?.excerpt == "첫 줄 둘째 줄")
    }

    @Test("긴 본문은 말줄임표까지 포함해 상한 길이로 자른다")
    func truncatesLongContent() {
        let long = String(repeating: "가", count: 200)

        let snapshot = WidgetSnapshot(from: [note(id: "1", content: long, createdAt: now)], generatedAt: now)
        let excerpt = snapshot.notes.first?.excerpt ?? ""

        #expect(excerpt.count == WidgetSnapshot.excerptLimit)
        #expect(excerpt.hasSuffix("…"))
    }

    @Test("상한과 같은 길이는 자르지 않는다")
    func keepsContentAtLimit() {
        let exact = String(repeating: "나", count: WidgetSnapshot.excerptLimit)

        let snapshot = WidgetSnapshot(from: [note(id: "1", content: exact, createdAt: now)], generatedAt: now)

        #expect(snapshot.notes.first?.excerpt == exact)
    }

    /// 사진만 붙인 노트는 본문이 빈다. 빈 줄로 두면 위젯에 아무것도 없는 칸이 생긴다.
    @Test("본문이 빈 노트는 대체 문구로 보여준다")
    func showsPlaceholderForEmptyContent() {
        let snapshot = WidgetSnapshot(from: [note(id: "1", content: "   \n ", createdAt: now)], generatedAt: now)

        #expect(snapshot.notes.first?.excerpt == WidgetSnapshot.emptyContentPlaceholder)
    }

    @Test("보여줄 노트가 없으면 빈 스냅샷이다")
    func emptyWhenNothingToShow() {
        let snapshot = WidgetSnapshot(
            from: [note(id: "휴지통", content: "휴지통", createdAt: now, deletedAt: now)],
            generatedAt: now
        )

        #expect(snapshot.isEmpty)
        #expect(WidgetSnapshot.empty.isEmpty)
    }
}

@Suite("위젯 스냅샷 저장소")
struct WidgetSnapshotStoreTests {
    private func makeStore() throws -> WidgetSnapshotStore {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return WidgetSnapshotStore(containerURL: directory)
    }

    @Test("쓴 것을 그대로 읽는다")
    func roundTrips() throws {
        let store = try makeStore()
        let snapshot = WidgetSnapshot(
            notes: [WidgetNote(id: "1", excerpt: "메모", createdAt: Date(timeIntervalSince1970: 1_700_000_000))],
            generatedAt: Date(timeIntervalSince1970: 1_700_000_001)
        )

        try store.write(snapshot)

        #expect(store.read() == snapshot)
    }

    /// 아직 앱을 한 번도 켜지 않았으면 파일이 없다. 위젯은 그래도 그려져야 한다.
    @Test("파일이 없으면 빈 스냅샷을 돌려준다")
    func missingFileReadsAsEmpty() throws {
        let store = try makeStore()

        #expect(store.read() == .empty)
    }

    /// 쓰다가 앱이 죽으면 반쯤 쓴 파일이 남는다 — 위젯이 거기서 멈추면 안 된다.
    @Test("깨진 파일도 빈 스냅샷으로 읽는다")
    func corruptFileReadsAsEmpty() throws {
        let store = try makeStore()
        try store.write(WidgetSnapshot(notes: [], generatedAt: Date()))
        try Data("망가진 내용".utf8).write(to: store.fileURL)

        #expect(store.read() == .empty)
    }

    @Test("나중에 쓴 스냅샷이 앞의 것을 덮는다")
    func overwritesPrevious() throws {
        let store = try makeStore()
        try store.write(WidgetSnapshot(
            notes: [WidgetNote(id: "옛것", excerpt: "옛것", createdAt: Date(timeIntervalSince1970: 1))],
            generatedAt: Date(timeIntervalSince1970: 1)
        ))

        try store.write(WidgetSnapshot(
            notes: [WidgetNote(id: "새것", excerpt: "새것", createdAt: Date(timeIntervalSince1970: 2))],
            generatedAt: Date(timeIntervalSince1970: 2)
        ))

        #expect(store.read().notes.map(\.id) == ["새것"])
    }

    /// 앱·공유확장이 이미 쓰는 그룹을 그대로 쓴다. 새 그룹은 포털 수작업을 부른다.
    @Test("공유 수신함과 같은 App Group을 쓴다")
    func usesSharedAppGroup() {
        #expect(WidgetSnapshotStore.appGroupID == SharedInbox.appGroupID)
    }
}

@Suite("위젯 딥링크")
struct WidgetDeepLinkTests {
    /// 위젯 탭 → 앱의 기존 작성 경로. 새 라우팅을 만들지 않는다.
    @Test("빠른 작성 링크는 작성 화면으로 해석된다")
    func quickComposeOpensComposer() {
        #expect(DropLink(url: DropLink.quickComposeURL) == .compose(text: nil))
    }

    @Test("노트 줄을 누르면 그 노트로 간다")
    func noteRowOpensThatNote() {
        #expect(DropLink(url: DropLink.noteURL(id: "abc-123")) == .note(id: "abc-123"))
    }
}
