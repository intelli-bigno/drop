import Foundation

/// DB의 `attachments.type`. 서버가 새 종류를 먼저 내보내도 목록이 통째로
/// 깨지지 않도록 `unknown`을 둔다.
public enum AttachmentType: String, Sendable, Codable, Equatable {
    case image, audio, video, file, text, instagram, youtube
    case unknown

    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = AttachmentType(rawValue: raw) ?? .unknown
    }
}

public struct Attachment: Sendable, Equatable, Hashable, Identifiable, Codable {
    public let id: String
    public let noteID: String
    public let type: AttachmentType
    public let storagePath: String
    public let filename: String?
    public let mimeType: String?
    public let size: Int?
    public let originalURL: String?
    public let authorName: String?
    public let authorURL: String?
    public let caption: String?
    public let createdAt: Date

    private enum CodingKeys: String, CodingKey {
        case id
        case noteID = "noteId"
        case type
        case storagePath
        case filename
        case mimeType
        case size
        case originalURL = "originalUrl"
        case authorName
        case authorURL = "authorUrl"
        case caption
        case createdAt
    }

    public init(
        id: String,
        noteID: String,
        type: AttachmentType,
        storagePath: String,
        filename: String? = nil,
        mimeType: String? = nil,
        size: Int? = nil,
        originalURL: String? = nil,
        authorName: String? = nil,
        authorURL: String? = nil,
        caption: String? = nil,
        createdAt: Date
    ) {
        self.id = id
        self.noteID = noteID
        self.type = type
        self.storagePath = storagePath
        self.filename = filename
        self.mimeType = mimeType
        self.size = size
        self.originalURL = originalURL
        self.authorName = authorName
        self.authorURL = authorURL
        self.caption = caption
        self.createdAt = createdAt
    }

    public var isImage: Bool { type == .image }
    public var isVideo: Bool { type == .video }
    public var isLink: Bool { type == .instagram || type == .youtube }
    public var isMedia: Bool { isImage || isVideo || type == .audio }
    public var isFile: Bool { type == .file || type == .text }

    /// Flutter `formattedSize`와 같은 표기를 유지한다.
    public var formattedSize: String {
        guard let size else { return "" }
        if size < 1024 { return "\(size) B" }
        if size < 1024 * 1024 { return String(format: "%.1f KB", Double(size) / 1024) }
        return String(format: "%.1f MB", Double(size) / (1024 * 1024))
    }
}
