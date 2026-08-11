import Foundation

/// 노트를 만든 곳. #21에서 MCP로 만든 노트가 CHECK 제약에 걸린 이력이 있어,
/// 서버가 아직 우리가 모르는 값을 보내도 목록 전체가 깨지지 않도록 `unknown`을 둔다.
public enum NoteSource: String, Sendable, Codable, Equatable {
    case mobile, desktop, web, mcp
    case unknown

    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = NoteSource(rawValue: raw) ?? .unknown
    }
}

/// 목록 화면의 상단 탭.
public enum NoteViewMode: String, Sendable, CaseIterable {
    case active, archived, trash
}

/// 목록 화면의 카테고리 필터.
public enum NoteCategory: String, Sendable, CaseIterable {
    case all, links, media, files
}

public struct Note: Sendable, Equatable, Identifiable, Codable {
    public let id: String
    public let displayID: Int
    public let content: String
    public let parentID: String?
    public let attachments: [Attachment]
    public let tags: [Tag]
    public let createdAt: Date
    public let updatedAt: Date
    public let source: NoteSource
    public let archivedAt: Date?
    public let deletedAt: Date?
    public let isDeleted: Bool
    public let hasLink: Bool
    public let hasMedia: Bool
    public let hasFiles: Bool
    public let isLocked: Bool
    public let isPinned: Bool
    public let pinnedAt: Date?
    public let priority: Int

    private enum CodingKeys: String, CodingKey {
        case id
        case displayID = "displayId"
        case content
        case parentID = "parentId"
        case attachments
        case tags
        case createdAt
        case updatedAt
        case source
        case archivedAt
        case deletedAt
        case isDeleted
        case hasLink
        case hasMedia
        case hasFiles
        case isLocked
        case isPinned
        case pinnedAt
        case priority
    }

    public init(
        id: String,
        displayID: Int,
        content: String,
        parentID: String? = nil,
        attachments: [Attachment] = [],
        tags: [Tag] = [],
        createdAt: Date,
        updatedAt: Date,
        source: NoteSource,
        archivedAt: Date? = nil,
        deletedAt: Date? = nil,
        isDeleted: Bool = false,
        hasLink: Bool = false,
        hasMedia: Bool = false,
        hasFiles: Bool = false,
        isLocked: Bool = false,
        isPinned: Bool = false,
        pinnedAt: Date? = nil,
        priority: Int = 0
    ) {
        self.id = id
        self.displayID = displayID
        self.content = content
        self.parentID = parentID
        self.attachments = attachments
        self.tags = tags
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.source = source
        self.archivedAt = archivedAt
        self.deletedAt = deletedAt
        self.isDeleted = isDeleted
        self.hasLink = hasLink
        self.hasMedia = hasMedia
        self.hasFiles = hasFiles
        self.isLocked = isLocked
        self.isPinned = isPinned
        self.pinnedAt = pinnedAt
        self.priority = priority
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(String.self, forKey: .id)
        displayID = try container.decode(Int.self, forKey: .displayID)
        // DB에서는 null이 될 수 있지만 화면에서는 항상 문자열이어야 한다.
        content = try container.decodeIfPresent(String.self, forKey: .content) ?? ""
        parentID = try container.decodeIfPresent(String.self, forKey: .parentID)
        // 목록 쿼리가 select를 줄이면 관계가 통째로 빠진다 — 없는 것과 빈 것을 같게 본다.
        attachments = try container.decodeIfPresent([Attachment].self, forKey: .attachments) ?? []
        tags = try container.decodeIfPresent([Tag].self, forKey: .tags) ?? []
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        source = try container.decode(NoteSource.self, forKey: .source)
        archivedAt = try container.decodeIfPresent(Date.self, forKey: .archivedAt)
        deletedAt = try container.decodeIfPresent(Date.self, forKey: .deletedAt)
        isDeleted = try container.decodeIfPresent(Bool.self, forKey: .isDeleted) ?? false
        hasLink = try container.decodeIfPresent(Bool.self, forKey: .hasLink) ?? false
        hasMedia = try container.decodeIfPresent(Bool.self, forKey: .hasMedia) ?? false
        hasFiles = try container.decodeIfPresent(Bool.self, forKey: .hasFiles) ?? false
        isLocked = try container.decodeIfPresent(Bool.self, forKey: .isLocked) ?? false
        isPinned = try container.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
        pinnedAt = try container.decodeIfPresent(Date.self, forKey: .pinnedAt)
        priority = try container.decodeIfPresent(Int.self, forKey: .priority) ?? 0
    }

    public var isReply: Bool { parentID != nil }
    public var isArchived: Bool { archivedAt != nil }
    public var isInTrash: Bool { deletedAt != nil }
    public var isActive: Bool { !isArchived && !isInTrash }

    public func matches(viewMode: NoteViewMode) -> Bool {
        switch viewMode {
        case .active: isActive
        case .archived: isArchived
        case .trash: isInTrash
        }
    }

    public func matches(category: NoteCategory) -> Bool {
        switch category {
        case .all: true
        case .links: hasLink
        case .media: hasMedia
        case .files: hasFiles
        }
    }
}
