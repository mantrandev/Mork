import MorkDomain
import Foundation

public final class GitCommandRepositoryImpl: GitCommandRepositoryProtocol {
    private let executor: GitCommandExecuting

    public init(executor: GitCommandExecuting) {
        self.executor = executor
    }

    public func run(arguments: [String]) async throws {
        try await executor.write(arguments, allowedExitCodes: nil)
    }
}
