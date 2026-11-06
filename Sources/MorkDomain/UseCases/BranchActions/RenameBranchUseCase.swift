import Foundation

public protocol RenameBranchUseCaseProtocol: Sendable {
    func execute(branch: Branch, newName: String, existingNames: [String], alsoOnRemote remote: String?) async throws
}

public final class RenameBranchUseCase: RenameBranchUseCaseProtocol {
    private let branches: BranchActionsRepositoryProtocol
    private let remote: RemoteRepositoryProtocol
    private let remotes: RemoteManagementRepositoryProtocol

    public init(branches: BranchActionsRepositoryProtocol, remote: RemoteRepositoryProtocol, remotes: RemoteManagementRepositoryProtocol) {
        self.branches = branches
        self.remote = remote
        self.remotes = remotes
    }

    public func execute(branch: Branch, newName: String, existingNames: [String], alsoOnRemote remoteName: String?) async throws {
        guard !branch.isRemote else { throw BranchActionError.remoteBranchRename(branch.name) }
        let newName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard newName != branch.name else { return }
        try BranchNameRules.validate(newName, existing: existingNames.filter { $0 != branch.name })
        try await branches.renameBranch(branch.name, to: newName)
        guard let remoteName else { return }
        try await remote.push(options: PushOptions(remote: remoteName, branch: newName, setUpstream: true, includeTags: false, forceWithLease: false))
        try await remotes.deleteRemoteBranch(named: branch.name, onRemote: remoteName)
    }
}
