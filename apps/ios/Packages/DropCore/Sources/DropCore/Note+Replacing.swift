import Foundation

/// `Note`는 값 타입이라 부분 수정에는 새 값을 만든다.
/// 옵셔널 필드를 "그대로 두기"와 "비우기"로 구분해야 해서, 인자를 이중 옵셔널로 받는다.
public extension Note {
    func replacing(
        content: String? = nil,
        attachments: [Attachment]? = nil,
        tags: [Tag]? = nil,
        updatedAt: Date? = nil,
        archivedAt: Date?? = nil,
        deletedAt: Date?? = nil,
        hasLink: Bool? = nil,
        hasMedia: Bool? = nil,
        hasFiles: Bool? = nil,
        isLocked: Bool? = nil,
        isPinned: Bool? = nil,
        pinnedAt: Date?? = nil,
        priority: Int? = nil
    ) -> Note {
        Note(
            id: id,
            displayID: displayID,
            content: content ?? self.content,
            parentID: parentID,
            attachments: attachments ?? self.attachments,
            tags: tags ?? self.tags,
            createdAt: createdAt,
            updatedAt: updatedAt ?? self.updatedAt,
            source: source,
            archivedAt: archivedAt ?? self.archivedAt,
            deletedAt: deletedAt ?? self.deletedAt,
            isDeleted: (deletedAt ?? self.deletedAt) != nil,
            hasLink: hasLink ?? self.hasLink,
            hasMedia: hasMedia ?? self.hasMedia,
            hasFiles: hasFiles ?? self.hasFiles,
            isLocked: isLocked ?? self.isLocked,
            isPinned: isPinned ?? self.isPinned,
            pinnedAt: pinnedAt ?? self.pinnedAt,
            priority: priority ?? self.priority
        )
    }
}
