#if DEBUG
import DropCore
import Foundation
import UIKit

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

    /// 댓글 표본. 뱃지가 붙는 노트(1·2)와 하나도 없는 노트를 함께 둔다 —
    /// 0이면 뱃지를 그리지 않는다는 규칙을 눈으로 확인하기 위한 것이다.
    @MainActor
    static func makeCommentsRepository() -> any CommentsRepository {
        InMemoryCommentsRepository(comments: sampleComments)
    }

    /// 썸네일 렌더링 경로를 자격증명 없이도 확인하기 위해 임시 파일 URL을 준다.
    @MainActor
    static func attachmentURL(for attachment: Attachment) -> URL? {
        guard attachment.isImage || attachment.isVideo else { return nil }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("preview-\(attachment.id).png")
        if !FileManager.default.fileExists(atPath: url.path) {
            try? samplePNG(seed: attachment.id).write(to: url)
        }
        return url
    }

    /// 색만 다른 단색 PNG. 그림 내용은 중요하지 않고, 실제로 그려지는지가 중요하다.
    private static func samplePNG(seed: String) -> Data {
        let size = CGSize(width: 240, height: 240)
        let hue = Double(abs(seed.hashValue) % 100) / 100
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            UIColor(hue: hue, saturation: 0.5, brightness: 0.9, alpha: 1).setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
        return image.pngData() ?? Data()
    }

    private static var sampleComments: [NoteComment] {
        let now = Date()
        func comment(_ id: String, note: String, _ body: String, minutesAgo: Double) -> NoteComment {
            let at = now.addingTimeInterval(-60 * minutesAgo)
            return NoteComment(id: id, noteID: note, body: body, createdAt: at, updatedAt: at)
        }

        return [
            comment("c1", note: "1", "M3까지는 왔는데 위젯이 아직 남았다.", minutesAgo: 90),
            comment("c2", note: "1", "위젯은 BRU-35에서 따로 본다.", minutesAgo: 40),
            comment("c3", note: "1", "확인.", minutesAgo: 5),
            comment("c4", note: "2", "원두는 지난번 것으로.", minutesAgo: 30),
        ]
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
                isPinned: true, pinnedAt: now, priority: 3
            ),
            Note(
                id: "2", displayID: 11,
                content: "장보기: 우유, 커피 원두, 사과",
                tags: [tag("생활")],
                createdAt: now.addingTimeInterval(-3600), updatedAt: now, source: .desktop,
                priority: 2
            ),
            // 계층 표본 (BRU-60). 답글은 자기 시각이 아니라 부모의 섹션에 붙어야 한다 —
            // 아래 두 답글은 부모("장보기", 1시간 전)보다 나중에 쓰였다.
            Note(
                id: "2-1", displayID: 17,
                content: "원두는 지난번 것으로",
                parentID: "2",
                createdAt: now.addingTimeInterval(-1800), updatedAt: now, source: .desktop
            ),
            Note(
                id: "2-1-1", displayID: 18,
                content: "품절이면 다른 것도 괜찮다",
                parentID: "2-1",
                createdAt: now.addingTimeInterval(-900), updatedAt: now, source: .desktop
            ),
            // 부모가 보관함에 있어 최상위로 올라오는 답글. 화살표 표시가 붙어야 한다.
            Note(
                id: "4-1", displayID: 19,
                content: "회고에서 나온 후속 — 부모는 보관함에 있다",
                parentID: "4",
                createdAt: now.addingTimeInterval(-7200), updatedAt: now, source: .desktop
            ),
            // 한 줄로 줄인 뒤에도 긴 본문이 줄을 밀지 않는지 눈으로 보기 위한 표본.
            Note(
                id: "6", displayID: 14,
                content: "긴 본문은 한 줄에서 잘려야 한다 — 목록은 훑는 자리이고 다 읽는 자리는 컴포저다. "
                    + "이 문장이 두 줄로 내려가면 한 화면에 들어오는 노트 수가 다시 줄어든다.",
                tags: [tag("설계"), tag("iOS"), tag("BRU-49")],
                createdAt: now.addingTimeInterval(-5400), updatedAt: now, source: .desktop,
                priority: 1
            ),
            // 마크다운 표본 (BRU-37). 목록에서는 기호가 걷힌 한 줄로 보이고,
            // 컴포저의 미리보기에서 제목·목록·체크박스·코드·인용·링크가 서야 한다.
            Note(
                id: "9", displayID: 20,
                content: """
                # 이번 주 정리

                **굵게**와 *기울임*, 그리고 `인라인 코드`.

                - [x] 파서를 DropCore에 두기
                - [ ] 뷰어 붙이기
                  - 목록 안의 목록
                - [ ] 편집기 툴바

                1. 첫째
                2. 둘째

                > 저장 형식은 평문 마크다운 그대로다.

                ```swift
                let document = MarkdownParser().parse(note.content)
                ```

                ---

                [이슈 보기](https://linear.app/intellieffect/issue/BRU-37)
                """,
                tags: [tag("설계")],
                createdAt: now.addingTimeInterval(-300), updatedAt: now, source: .desktop,
                priority: 2
            ),
            Note(
                id: "7", displayID: 15,
                content: "어제 적어 둔 메모",
                createdAt: now.addingTimeInterval(-100_000), updatedAt: now, source: .mobile
            ),
            Note(
                id: "8", displayID: 16,
                content: "사흘 전 링크",
                createdAt: now.addingTimeInterval(-260_000), updatedAt: now, source: .web,
                hasLink: true
            ),
            Note(
                id: "5", displayID: 13,
                content: "제주 사진 몇 장",
                attachments: (1...3).map { index in
                    DropCore.Attachment(
                        id: "img\(index)", noteID: "5", type: .image,
                        storagePath: "u/5/img\(index).png", filename: "img\(index).png",
                        mimeType: "image/png", size: 240_000, createdAt: now
                    )
                },
                tags: [tag("사진")],
                createdAt: now.addingTimeInterval(-600), updatedAt: now, source: .mobile,
                hasMedia: true
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
