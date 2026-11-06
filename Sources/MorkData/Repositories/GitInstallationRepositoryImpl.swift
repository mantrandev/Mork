import MorkDomain
import Foundation

public final class GitInstallationRepositoryImpl: GitInstallationRepositoryProtocol {
    private let executor: GitCommandExecuting
    private let searchPath: String?

    public init(executor: GitCommandExecuting, searchPath: String? = ProcessInfo.processInfo.environment["PATH"]) {
        self.executor = executor
        self.searchPath = searchPath
    }

    public func installation() async throws -> GitInstallation {
        GitInstallation(path: GitExecutableLocator.locate(searchPath: searchPath), versionOutput: try await executor.read(["--version"]))
    }
}

enum GitExecutableLocator {
    static func locate(searchPath: String?) -> String? {
        (searchPath ?? "")
            .split(separator: ":")
            .map { URL(fileURLWithPath: String($0)).appendingPathComponent("git").path }
            .first { FileManager.default.isExecutableFile(atPath: $0) }
    }
}
