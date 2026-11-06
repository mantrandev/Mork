import MorkDomain
import Foundation

public final class BisectRepositoryImpl: BisectRepositoryProtocol {
    private static let onlySkippedExitCode: Int32 = 2

    private let executor: GitCommandExecuting

    public init(executor: GitCommandExecuting) {
        self.executor = executor
    }

    public func session() async throws -> BisectSession? {
        let paths = GitOutputParser.lines(try await executor.read([
            "rev-parse", "--path-format=absolute", "--git-path", "BISECT_LOG", "--git-path", "BISECT_START"
        ]))
        guard paths.count == 2, let logText = Self.contents(of: paths[0]) else { return nil }
        let originalHead = (Self.contents(of: paths[1]) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let log = BisectParser.log(logText)
        guard case .testing = log.state else {
            return BisectSession(originalHead: originalHead, entries: log.entries, state: log.state)
        }
        async let progress = progress()
        async let candidate = head()
        return try await BisectSession(originalHead: originalHead, entries: log.entries, state: .testing(progress: progress, candidate: candidate))
    }

    public func start() async throws -> BisectState? {
        BisectParser.outcome(try await executor.write(["bisect", "start"]))
    }

    public func mark(_ mark: BisectMark, revision: String?) async throws -> BisectState? {
        let output = try await executor.write(["bisect", mark.rawValue] + (revision.map { [$0] } ?? []), allowedExitCodes: [0, Self.onlySkippedExitCode])
        return BisectParser.outcome(output)
    }

    public func reset(to revision: String?) async throws {
        try await executor.write(["bisect", "reset"] + (revision.map { [$0] } ?? []))
    }

    public func log() async throws -> String {
        try await executor.read(["bisect", "log"])
    }

    public func revisionExists(_ revision: String) async throws -> Bool {
        try await !executor.read(["rev-parse", "--verify", "--quiet", "\(revision)^{commit}"], allowedExitCodes: [0, 1]).isEmpty
    }

    private func progress() async -> BisectProgress? {
        let output = try? await executor.read(["rev-list", "--bisect-vars", "refs/bisect/bad", "--not", "--glob=refs/bisect/good-*"])
        return output.flatMap(BisectParser.progress(bisectVars:))
    }

    private func head() async throws -> BisectCommit? {
        let fields = try await executor.read(["log", "-1", "--format=%H%x1f%s", "HEAD"])
            .trimmingCharacters(in: .newlines)
            .split(separator: GitOutputParser.separator, maxSplits: 1, omittingEmptySubsequences: false)
        guard let hash = fields.first, !hash.isEmpty else { return nil }
        return BisectCommit(hash: String(hash), subject: fields.count > 1 ? String(fields[1]) : "")
    }

    private static func contents(of path: String) -> String? {
        FileManager.default.contents(atPath: path).map { String(decoding: $0, as: UTF8.self) }
    }
}
