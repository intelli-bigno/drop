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
            // 한 줄로 줄인 뒤에도 긴 본문이 줄을 밀지 않는지 눈으로 보기 위한 표본.
            Note(
                id: "6", displayID: 14,
                content: "긴 본문은 한 줄에서 잘려야 한다 — 목록은 훑는 자리이고 다 읽는 자리는 컴포저다. "
                    + "이 문장이 두 줄로 내려가면 한 화면에 들어오는 노트 수가 다시 줄어든다.",
                tags: [tag("설계"), tag("iOS"), tag("BRU-49")],
                createdAt: now.addingTimeInterval(-5400), updatedAt: now, source: .desktop,
                priority: 1
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
