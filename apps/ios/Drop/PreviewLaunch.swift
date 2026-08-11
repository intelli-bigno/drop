#if DEBUG
import DropCore
import Foundation

/// 자격증명 없이 화면을 띄워 보기 위한 디버그 전용 경로.
///
/// `-dropPreview` 인자로 실행하면 인증을 건너뛰고 인메모리 데이터를 쓴다.
/// 릴리스 빌드에는 이 파일 자체가 들어가지 않는다.
enum PreviewLaunch {
    static var isActive: Bool {
        ProcessInfo.processInfo.arguments.contains("-dropPreview")
    }

    @MainActor
    static func makeRepository() -> any NotesRepository {
        InMemoryNotesRepository(notes: sampleNotes)
    }

    private static var sampleNotes: [Note] {
        let now = Date()
        func tag(_ name: String) -> DropCore.Tag {
            DropCore.Tag(id: name, name: name, createdAt: now)
        }

        return [
            Note(
                id: "1", displayID: 12,
                content: "iOS 네이티브 전환 M3 — 홈 화면까지 올라왔다.",
                tags: [tag("개발")],
                createdAt: now.addingTimeInterval(-120), updatedAt: now, source: .mobile,
                isPinned: true, pinnedAt: now
            ),
            Note(
                id: "2", displayID: 11,
                content: "장보기: 우유, 커피 원두, 사과",
                tags: [tag("생활")],
                createdAt: now.addingTimeInterval(-3600), updatedAt: now, source: .desktop
            ),
            Note(
                id: "3", displayID: 10,
                content: "회의 녹음",
                attachments: [
                    DropCore.Attachment(
                        id: "a1", noteID: "3", type: .audio, storagePath: "u/3/a1.m4a",
                        filename: "a1.m4a", mimeType: "audio/m4a", size: 1_536_000, createdAt: now
                    ),
                ],
                createdAt: now.addingTimeInterval(-90000), updatedAt: now, source: .mcp,
                hasMedia: true
            ),
            Note(
                id: "4", displayID: 9,
                content: "보관해 둔 지난 분기 회고",
                createdAt: now.addingTimeInterval(-400000), updatedAt: now, source: .web,
                archivedAt: now.addingTimeInterval(-100000)
            ),
        ]
    }
}
#endif
