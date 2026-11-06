import MorkDomain
import Foundation

public struct BranchActionsDependencies: Sendable {
    public let createBranch: CreateBranchFromBranchUseCaseProtocol
    public let createTag: CreateTagAtBranchUseCaseProtocol
    public let rename: RenameBranchUseCaseProtocol
    public let fastForward: FastForwardBranchUseCaseProtocol
    public let loadPullRequestURL: LoadPullRequestURLUseCaseProtocol

    public init(
        createBranch: CreateBranchFromBranchUseCaseProtocol,
        createTag: CreateTagAtBranchUseCaseProtocol,
        rename: RenameBranchUseCaseProtocol,
        fastForward: FastForwardBranchUseCaseProtocol,
        loadPullRequestURL: LoadPullRequestURLUseCaseProtocol
    ) {
        self.createBranch = createBranch
        self.createTag = createTag
        self.rename = rename
        self.fastForward = fastForward
        self.loadPullRequestURL = loadPullRequestURL
    }
}
