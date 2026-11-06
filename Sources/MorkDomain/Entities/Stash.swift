import Foundation

public struct Stash: Identifiable, Hashable, Sendable {
    public let reference: String
    public let message: String

    public init(reference: String, message: String) {
        self.reference = reference
        self.message = message
    }

    public var id: String { reference }
}
