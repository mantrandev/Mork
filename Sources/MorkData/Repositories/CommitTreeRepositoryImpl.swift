import MorkDomain
import Foundation

public final class CommitTreeRepositoryImpl: CommitTreeRepositoryProtocol {
    private let executor: GitCommandExecuting

    public init(executor: GitCommandExecuting) {
        self.executor = executor
    }

    public func entries(at revision: String, in directory: String) async throws -> [TreeEntry] {
        TreeEntryParser.parse(try await executor.read(TreeEntryParser.arguments(revision: revision, directory: directory)), directory: directory)
    }
}
