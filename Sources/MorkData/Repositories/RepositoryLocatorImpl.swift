import MorkDomain
import Foundation

public final class RepositoryLocatorImpl: RepositoryLocatorProtocol {
    private let makeExecutor: @Sendable (URL) -> GitCommandExecuting

    public init(makeExecutor: @escaping @Sendable (URL) -> GitCommandExecuting) {
        self.makeExecutor = makeExecutor
    }

    public func locateRepository(containing url: URL) async throws -> URL {
        let path = try await makeExecutor(url).read(["rev-parse", "--show-toplevel"])
        return URL(fileURLWithPath: path.trimmingCharacters(in: .newlines))
    }

    public func initializeRepository(at url: URL) async throws {
        try await makeExecutor(url).write(["init", "-b", "main"])
    }
}
