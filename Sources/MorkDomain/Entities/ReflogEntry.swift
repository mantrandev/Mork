import Foundation

public struct ReflogEntry: Identifiable, Hashable, Sendable {
    public let selector: String
    public let commit: Commit
    public let action: String
    public let message: String
    public let date: Date

    public init(selector: String, commit: Commit, action: String, message: String, date: Date) {
        self.selector = selector
        self.commit = commit
        self.action = action
        self.message = message
        self.date = date
    }

    public var id: String { selector }
}
