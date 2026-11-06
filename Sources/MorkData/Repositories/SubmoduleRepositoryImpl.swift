import MorkDomain
import Foundation

public final class SubmoduleRepositoryImpl: SubmoduleRepositoryProtocol {
    private static let modulesFile = ".gitmodules"
    private static let modulesPattern = "^submodule\\..*\\.(path|url)$"

    private let executor: GitStreamingCommandExecuting
    private let root: URL
    private let configOverrides: [String]

    public init(executor: GitStreamingCommandExecuting, root: URL, configOverrides: [String] = []) {
        self.executor = executor
        self.root = root
        self.configOverrides = configOverrides
    }

    public func submodules() async throws -> [Submodule] {
        guard FileManager.default.fileExists(atPath: root.appendingPathComponent(Self.modulesFile).path) else { return [] }
        async let status = executor.read(["submodule", "status", "--recursive"], allowedExitCodes: nil)
        async let modules = executor.read(["config", "-f", Self.modulesFile, "--null", "--get-regexp", Self.modulesPattern], allowedExitCodes: nil)
        return try await SubmoduleStatusParser.parse(status: status, modules: modules)
    }

    public func updateSubmodules(progress: @escaping @Sendable (String) -> Void) async throws {
        _ = try await executor.run(
            configOverrides + ["submodule", "update", "--init", "--recursive", "--progress"],
            kind: .write,
            allowedExitCodes: [0],
            onProgress: progress
        )
    }

    public func addSubmodule(url: String, path: String) async throws {
        try await executor.write(configOverrides + ["submodule", "add", "--", url, path])
    }

    public func syncSubmodules() async throws {
        try await executor.write(["submodule", "sync", "--recursive"])
    }
}
