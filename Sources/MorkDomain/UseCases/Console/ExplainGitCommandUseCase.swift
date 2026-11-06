import Foundation

public protocol ExplainGitCommandUseCaseProtocol: Sendable {
    func execute(arguments: [String]) -> String?
}

public final class ExplainGitCommandUseCase: ExplainGitCommandUseCaseProtocol {
    public init() {}

    public func execute(arguments: [String]) -> String? {
        Lessons.explain(arguments)
    }
}
