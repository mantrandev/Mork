import Foundation

public struct Tag: Identifiable, Hashable, Sendable {
    public let name: String
    public let isAnnotated: Bool
    public let createdAt: Date?

    public init(name: String, isAnnotated: Bool, createdAt: Date? = nil) {
        self.name = name
        self.isAnnotated = isAnnotated
        self.createdAt = createdAt
    }

    public var id: String { name }
    public var reference: String { "refs/tags/\(name)" }
}
