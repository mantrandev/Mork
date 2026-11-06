import Foundation

public enum ResetMode: String, CaseIterable, Sendable {
    case soft
    case mixed
    case hard

    public var flag: String { "--\(rawValue)" }
    public var discardsUncommittedChanges: Bool { self == .hard }
}

public enum RevisionOperation: Sendable, Equatable {
    case cherryPick
    case revert
}

extension RepositoryState {
    public var revisionOperation: RevisionOperation? {
        switch self {
        case .cherryPicking: .cherryPick
        case .reverting: .revert
        case .clean, .merging, .rebasing: nil
        }
    }
}

extension RepositorySnapshot {
    private static let detachedHeadDecoration = "HEAD"

    public var detachedHead: Commit? {
        guard currentBranch == nil else { return nil }
        return commits.first { $0.refNames.contains(Self.detachedHeadDecoration) }
    }
}

extension Commit {
    private static let firstParent = 1

    public var mainline: Int? { isMerge ? Self.firstParent : nil }
}

extension Sequence<Commit> {
    public var mainline: Int? { first(where: \.isMerge)?.mainline }
}

extension WorkingCopyRepositoryProtocol {
    func requireCleanState() async throws {
        let state = try await state()
        guard state == .clean else { throw GitDomainError.operationInProgress(state) }
    }
}
