import Foundation

public struct Tag: Sendable, Equatable, Identifiable, Codable, Hashable {
    public let id: String
    public let name: String
    public let createdAt: Date

    public init(id: String, name: String, createdAt: Date) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
    }
}
