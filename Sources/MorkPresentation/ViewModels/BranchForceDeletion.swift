import MorkDomain
import Foundation

public struct BranchForceDeletion: Identifiable, Equatable, Sendable {
    public let branch: Branch
    public let alsoDeleteRemote: Bool
    public let reason: String

    public init(branch: Branch, alsoDeleteRemote: Bool, reason: String) {
        self.branch = branch
        self.alsoDeleteRemote = alsoDeleteRemote
        self.reason = reason
    }

    public var id: String { branch.fullName }
}
