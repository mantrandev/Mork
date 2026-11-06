import MorkDomain
import Foundation

public final class RepositoryInspectorImpl: RepositoryInspectorProtocol {
    private static let readmeNames = ["readme.md", "readme.markdown", "readme", "readme.txt"]
    private static let readmeByteLimit = 512 * 1024
    private static let kibibyte: Int64 = 1024

    private let makeExecutor: @Sendable (URL) -> GitCommandExecuting

    public init(makeExecutor: @escaping @Sendable (URL) -> GitCommandExecuting) {
        self.makeExecutor = makeExecutor
    }

    public func status(of repository: URL) async throws -> RepositoryStatusSummary {
        let executor = makeExecutor(repository)
        async let branch = branchName(using: executor)
        async let porcelain = executor.read(["status", "--porcelain", "-uno"])
        return RepositoryStatusSummary(branch: try await branch, isDirty: !(try await porcelain).isEmpty)
    }

    public func worktrees(of repository: URL) async throws -> [Worktree] {
        try await WorktreeRepositoryImpl(executor: makeExecutor(repository)).worktrees()
    }

    public func commonDirectory(of repository: URL) async throws -> URL {
        let path = try await makeExecutor(repository).read(["rev-parse", "--git-common-dir"]).trimmingCharacters(in: .newlines)
        let url = path.hasPrefix("/") ? URL(filePath: path, directoryHint: .notDirectory) : repository.appendingPathComponent(path)
        return URL(filePath: url.standardizedFileURL.path, directoryHint: .notDirectory)
    }

    public func overview(of repository: URL) async throws -> RepositoryOverview {
        let executor = makeExecutor(repository)
        async let changes = executor.read(["status", "--porcelain=v1", "-z"])
        async let size = repositorySize(using: executor)
        async let history = history(using: executor)
        async let remotes = RemoteManagementRepositoryImpl(executor: executor).remoteList()
        async let readme = Self.readme(in: repository)
        let (commitCount, initialCommitDate, lastCommitDate) = try await history
        return RepositoryOverview(
            changedFiles: GitOutputParser.status(try await changes).count,
            repositorySizeBytes: try await size,
            commitCount: commitCount,
            initialCommitDate: initialCommitDate,
            lastCommitDate: lastCommitDate,
            remotes: try await remotes,
            readme: await readme
        )
    }

    private func repositorySize(using executor: GitCommandExecuting) async throws -> Int64 {
        var values: [String: Int64] = [:]
        for line in try await executor.read(["count-objects", "-v"]).split(separator: "\n") {
            let parts = line.split(separator: ":", maxSplits: 1)
            guard parts.count == 2, let value = Int64(parts[1].trimmingCharacters(in: .whitespaces)) else { continue }
            values[String(parts[0])] = value
        }
        return ((values["size"] ?? 0) + (values["size-pack"] ?? 0)) * Self.kibibyte
    }

    private func history(using executor: GitCommandExecuting) async throws -> (Int, Date?, Date?) {
        guard try await executor.hasHead() else { return (0, nil, nil) }
        async let count = executor.read(["rev-list", "--count", "HEAD"])
        async let roots = executor.read(["log", "--max-parents=0", "--format=%aI", "HEAD"])
        async let last = executor.read(["log", "-1", "--format=%aI", "HEAD"])
        let commitCount = Int(try await count.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
        let initial = try await roots.split(separator: "\n").compactMap(Self.authorDate).min()
        return (commitCount, initial, Self.authorDate(try await last.trimmingCharacters(in: .whitespacesAndNewlines)))
    }

    private static func authorDate<S: StringProtocol>(_ text: S) -> Date? {
        try? Date(String(text), strategy: .iso8601)
    }

    private static func readme(in repository: URL) -> RepositoryReadme? {
        guard let entries = try? FileManager.default.contentsOfDirectory(atPath: repository.path) else { return nil }
        let files = entries.filter { name in
            var isDirectory: ObjCBool = false
            return FileManager.default.fileExists(atPath: repository.appendingPathComponent(name).path, isDirectory: &isDirectory) && !isDirectory.boolValue
        }
        for candidate in readmeNames {
            guard let name = files.filter({ $0.lowercased() == candidate }).sorted().first,
                  let handle = try? FileHandle(forReadingFrom: repository.appendingPathComponent(name)) else { continue }
            defer { try? handle.close() }
            guard let data = try? handle.read(upToCount: readmeByteLimit + 1) ?? Data() else { continue }
            let isTruncated = data.count > readmeByteLimit
            let text = String(decoding: isTruncated ? data.prefix(readmeByteLimit) : data, as: UTF8.self)
            return RepositoryReadme(fileName: name, text: text, isTruncated: isTruncated)
        }
        return nil
    }

    private func branchName(using executor: GitCommandExecuting) async throws -> String {
        if let name = try? await executor.read(["rev-parse", "--abbrev-ref", "HEAD"]).trimmingCharacters(in: .newlines), !name.isEmpty {
            return name
        }
        return try await executor.read(["symbolic-ref", "--short", "HEAD"]).trimmingCharacters(in: .newlines)
    }
}
