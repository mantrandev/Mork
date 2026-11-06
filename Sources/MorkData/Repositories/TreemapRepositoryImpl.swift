import MorkDomain
import Foundation

public final class TreemapRepositoryImpl: TreemapRepositoryProtocol {
    private let executor: GitCommandExecuting

    public init(executor: GitCommandExecuting) {
        self.executor = executor
    }

    public func files(at revision: String) async throws -> [TreemapFile] {
        guard try await executor.hasHead() else { return [] }
        return GitOutputParser.treemapFiles(try await executor.read(["ls-tree", "-r", "-l", "-z", revision]))
    }
}
