import Foundation

public protocol TagActionsRepositoryProtocol: Sendable {
    func details(of tag: Tag) async throws -> String
    func merge(_ tag: Tag) async throws
    func rebase(onto tag: Tag, autostash: Bool) async throws
    func delete(_ tag: Tag, from remote: String) async throws
}

public protocol DeleteTagFromRemotesUseCaseProtocol: Sendable {
    func execute(tag: Tag, remotes: [String]) async throws
}

public final class DeleteTagFromRemotesUseCase: DeleteTagFromRemotesUseCaseProtocol {
    private let tags: TagActionsRepositoryProtocol
    public init(tags: TagActionsRepositoryProtocol) { self.tags = tags }
    public func execute(tag: Tag, remotes: [String]) async throws {
        var deleted: [String] = []
        for remote in remotes {
            do {
                try await tags.delete(tag, from: remote)
                deleted.append(remote)
            } catch {
                let progress = deleted.isEmpty ? "" : "Already deleted from: \(deleted.joined(separator: ", ")). "
                throw NSError(domain: "TagDeletion", code: 1, userInfo: [NSLocalizedDescriptionKey:
                    "Could not delete tag '\(tag.name)' from '\(remote)': \(error.localizedDescription). \(progress)The local tag has not been deleted."])
            }
        }
    }
}

public protocol LoadTagDetailsUseCaseProtocol: Sendable {
    func execute(tag: Tag) async throws -> String
}

public final class LoadTagDetailsUseCase: LoadTagDetailsUseCaseProtocol {
    private let tags: TagActionsRepositoryProtocol
    public init(tags: TagActionsRepositoryProtocol) { self.tags = tags }
    public func execute(tag: Tag) async throws -> String { try await tags.details(of: tag) }
}

public protocol MergeTagUseCaseProtocol: Sendable {
    func execute(tag: Tag) async throws
}

public final class MergeTagUseCase: MergeTagUseCaseProtocol {
    private let tags: TagActionsRepositoryProtocol
    private let workingCopy: WorkingCopyRepositoryProtocol
    public init(tags: TagActionsRepositoryProtocol, workingCopy: WorkingCopyRepositoryProtocol) {
        self.tags = tags
        self.workingCopy = workingCopy
    }
    public func execute(tag: Tag) async throws {
        try await workingCopy.requireCleanState()
        try await tags.merge(tag)
    }
}

public protocol RebaseTagUseCaseProtocol: Sendable {
    func execute(tag: Tag, current: Branch?, autostash: Bool) async throws
}

public final class RebaseTagUseCase: RebaseTagUseCaseProtocol {
    private let tags: TagActionsRepositoryProtocol
    private let workingCopy: WorkingCopyRepositoryProtocol
    public init(tags: TagActionsRepositoryProtocol, workingCopy: WorkingCopyRepositoryProtocol) {
        self.tags = tags
        self.workingCopy = workingCopy
    }
    public func execute(tag: Tag, current: Branch?, autostash: Bool) async throws {
        guard current != nil else { throw GitDomainError.detachedHead }
        try await workingCopy.requireCleanState()
        if !autostash { try await workingCopy.requireNoUncommittedChanges() }
        try await tags.rebase(onto: tag, autostash: autostash)
    }
}
