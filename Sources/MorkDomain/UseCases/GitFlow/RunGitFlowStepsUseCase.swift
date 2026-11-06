import Foundation

public protocol RunGitFlowStepsUseCaseProtocol: Sendable {
    func execute(_ steps: [GitFlowStep]) async throws -> GitFlowOutcome
}

public final class RunGitFlowStepsUseCase: RunGitFlowStepsUseCaseProtocol {
    private let flow: GitFlowRepositoryProtocol

    public init(flow: GitFlowRepositoryProtocol) {
        self.flow = flow
    }

    public func execute(_ steps: [GitFlowStep]) async throws -> GitFlowOutcome {
        for (index, step) in steps.enumerated() {
            do {
                try await flow.run(step)
            } catch {
                guard step.isMerge, (try? await flow.isMerging()) == true else { throw error }
                return .stoppedOnConflict(step, remaining: Array(steps[(index + 1)...]))
            }
        }
        return .completed
    }
}
