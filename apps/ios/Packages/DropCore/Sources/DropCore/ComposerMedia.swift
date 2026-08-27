import Foundation

/// 작성 시트에서 고른 파일. 노트 id가 생기기 전에는 여기에만 있다 (BRU-131).
public struct PendingAttachment: Equatable, Identifiable, Sendable {
    public let id: UUID
    public let data: Data
    public let fileName: String
    public let type: AttachmentType

    public init(id: UUID = UUID(), data: Data, fileName: String, type: AttachmentType) {
        self.id = id
        self.data = data
        self.fileName = fileName
        self.type = type
    }
}

/// 고른 미디어가 어느 노트에 붙는지.
///
/// 홈의 PhotosPicker는 빈 노트를 새로 만들고 붙인다. 편집 시트는
/// 지금 고치고 있는 그 노트에 붙여야 한다 — 새 display_id가 생기면 안 된다.
public enum ComposerAttachmentDestination: Equatable, Sendable {
    /// 이미 있는 노트. 업로드는 이 id로 간다.
    case existing(noteID: String)
    /// 아직 id가 없다. 노트를 만든 뒤에 그 id로 붙인다.
    case createThenAttach
}

public enum ComposerAttachmentRouting {
    public static func destination(editingNoteID: String?) -> ComposerAttachmentDestination {
        if let editingNoteID {
            return .existing(noteID: editingNoteID)
        }
        return .createThenAttach
    }

    /// 업로드에 쓸 노트 id. 새 노트인데 아직 안 만들어졌으면 nil.
    public static func noteIDToAttach(
        destination: ComposerAttachmentDestination,
        createdNoteID: String?
    ) -> String? {
        switch destination {
        case let .existing(noteID):
            return noteID
        case .createThenAttach:
            return createdNoteID
        }
    }
}
