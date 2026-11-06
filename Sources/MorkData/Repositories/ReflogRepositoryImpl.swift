import MorkDomain
import Foundation

public final class ReflogRepositoryImpl: ReflogRepositoryProtocol {
    private let executor: GitCommandExecuting

    public init(executor: GitCommandExecuting) {
        self.executor = executor
    }

    public func reflog(limit: Int) async throws -> [ReflogEntry] {
        guard try await executor.hasHead() else { return [] }
        return ReflogParser.parse(try await executor.read(["reflog", "--date=unix", "-n", "\(limit)", "--format=\(ReflogParser.format)"]))
    }
}
