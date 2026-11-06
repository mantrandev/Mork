import MorkDomain
import Foundation

public final class LFSRepositoryImpl: LFSRepositoryProtocol {
    static let progressEnvironment = ["GIT_LFS_FORCE_PROGRESS": "1"]
    static let progressNote = "GIT_LFS_FORCE_PROGRESS=1 makes git-lfs print its progress even though Mork is not a terminal."

    private let executor: GitStreamingCommandExecuting

    public init(executor: GitStreamingCommandExecuting) {
        self.executor = executor
    }

    public func version() async throws -> String? {
        let output = try await executor.read(["lfs", "version"], allowedExitCodes: nil)
        let version = output.trimmingCharacters(in: .whitespacesAndNewlines)
        return version.hasPrefix("git-lfs/") ? version : nil
    }

    public func install() async throws {
        try await executor.write(["lfs", "install", "--local"])
    }

    public func trackedPatterns() async throws -> [String] {
        GitOutputParser.lfsTrackedPatterns(try await executor.read(["lfs", "track"]))
    }

    public func track(pattern: String) async throws {
        try await executor.write(["lfs", "track", pattern])
    }

    public func untrack(pattern: String) async throws {
        try await executor.write(["lfs", "untrack", pattern])
    }

    public func fetch(progress: @escaping @Sendable (String) -> Void) async throws {
        try await transfer(["lfs", "fetch"], progress: progress)
    }

    public func pull(progress: @escaping @Sendable (String) -> Void) async throws {
        try await transfer(["lfs", "pull"], progress: progress)
    }

    public func lfsPaths(_ paths: [String], revision: String?) async throws -> Set<String> {
        guard !paths.isEmpty else { return [] }
        let source = revision.map { ["--source=\($0)"] } ?? []
        let output = try await executor.run(
            ["check-attr"] + source + ["-z", "--stdin", "filter"],
            input: paths.joined(separator: "\0") + "\0",
            kind: .read,
            allowedExitCodes: [0]
        )
        return GitOutputParser.lfsFilteredPaths(output)
    }

    private func transfer(_ arguments: [String], progress: @escaping @Sendable (String) -> Void) async throws {
        _ = try await executor.run(
            arguments,
            environment: Self.progressEnvironment,
            notes: [Self.progressNote],
            kind: .write,
            allowedExitCodes: [0],
            onProgress: progress
        )
    }
}
