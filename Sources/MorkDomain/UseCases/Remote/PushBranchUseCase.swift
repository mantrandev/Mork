import Foundation

public protocol PushBranchUseCaseProtocol: Sendable {
    func execute(branch: Branch?) async throws
}

public final class PushBranchUseCase: PushBranchUseCaseProtocol {
    private static let preferredRemote = "origin"

    private let remote: RemoteRepositoryProtocol

    public init(remote: RemoteRepositoryProtocol) {
        self.remote = remote
    }

    public func execute(branch: Branch?) async throws {
        guard let branch else { throw GitDomainError.detachedHead }
        if branch.upstream != nil, !branch.isUpstreamGone {
            try await remote.push(branch, setUpstreamTo: nil)
            return
        }
        try await remote.push(branch, setUpstreamTo: try await chooseRemote())
    }

    private func chooseRemote() async throws -> String {
        let remotes = try await remote.remotes()
        if remotes.contains(Self.preferredRemote) { return Self.preferredRemote }
        guard let only = remotes.first else { throw GitDomainError.noRemote }
        guard remotes.count == 1 else { throw GitDomainError.ambiguousRemote(remotes) }
        return only
    }
}
