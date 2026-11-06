import Foundation

public protocol LoadGitFlowContextUseCaseProtocol: Sendable {
    func execute() async throws -> GitFlowContext
}

public final class LoadGitFlowContextUseCase: LoadGitFlowContextUseCaseProtocol {
    private let flow: GitFlowRepositoryProtocol

    public init(flow: GitFlowRepositoryProtocol) {
        self.flow = flow
    }

    public func execute() async throws -> GitFlowContext {
        async let configuration = flow.configuration()
        async let branches = flow.localBranches()
        async let tags = flow.tags()
        async let current = flow.currentBranch()
        async let hasCommits = flow.hasCommits()
        return try await GitFlowContext(
            configuration: GitFlowConfiguration(config: configuration),
            localBranches: branches,
            tags: tags,
            currentBranch: current,
            hasCommits: hasCommits
        )
    }
}
