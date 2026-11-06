import Foundation

public protocol DeleteRemoteBranchUseCaseProtocol: Sendable {
    func ensureDeletable(branch: Branch) async throws
    func execute(branch: Branch) async throws
}

public protocol SetUpstreamUseCaseProtocol: Sendable {
    func execute(upstream: Branch, branch: Branch?) async throws
}

public protocol UnsetUpstreamUseCaseProtocol: Sendable {
    func execute(branch: Branch) async throws
}

public final class DeleteRemoteBranchUseCase: DeleteRemoteBranchUseCaseProtocol {
    private let remotes: RemoteManagementRepositoryProtocol
    private let branches: BranchActionsRepositoryProtocol

    public init(remotes: RemoteManagementRepositoryProtocol, branches: BranchActionsRepositoryProtocol) {
        self.remotes = remotes
        self.branches = branches
    }

    public func ensureDeletable(branch: Branch) async throws {
        _ = try await deletableRemote(of: branch)
    }

    public func execute(branch: Branch) async throws {
        let remote = try await deletableRemote(of: branch)
        try await remotes.deleteRemoteBranch(named: branch.localName, onRemote: remote)
    }

    private func deletableRemote(of branch: Branch) async throws -> String {
        guard let remote = branch.remoteName else { throw RemoteValidationError.notRemoteBranch(branch.name) }
        if try await branches.defaultBranch(ofRemote: remote) == branch.localName {
            throw RemoteValidationError.defaultRemoteBranch(branch.name)
        }
        return remote
    }
}

public final class SetUpstreamUseCase: SetUpstreamUseCaseProtocol {
    private let remotes: RemoteManagementRepositoryProtocol

    public init(remotes: RemoteManagementRepositoryProtocol) {
        self.remotes = remotes
    }

    public func execute(upstream: Branch, branch: Branch?) async throws {
        guard let branch else { throw GitDomainError.detachedHead }
        guard upstream.fullName != branch.fullName else { return }
        try await remotes.setUpstream(of: branch.name, to: upstream.name)
    }
}

public final class UnsetUpstreamUseCase: UnsetUpstreamUseCaseProtocol {
    private let remotes: RemoteManagementRepositoryProtocol

    public init(remotes: RemoteManagementRepositoryProtocol) {
        self.remotes = remotes
    }

    public func execute(branch: Branch) async throws {
        guard !branch.isRemote, branch.upstream != nil else { return }
        try await remotes.unsetUpstream(of: branch.name)
    }
}
