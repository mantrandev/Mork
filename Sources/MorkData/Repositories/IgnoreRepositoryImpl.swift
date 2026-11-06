import MorkDomain
import Foundation

public final class IgnoreRepositoryImpl: IgnoreRepositoryProtocol {
    private let executor: GitCommandExecuting

    public init(executor: GitCommandExecuting) {
        self.executor = executor
    }

    public func contents(of target: IgnoreTarget) async throws -> String? {
        let file = try await location(of: target)
        guard FileManager.default.fileExists(atPath: file.path) else { return nil }
        return LosslessText.decode(try Data(contentsOf: file))
    }

    public func write(_ contents: String, to target: IgnoreTarget) async throws {
        let file = try await location(of: target)
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try LosslessText.encode(contents).write(to: file, options: .atomic)
    }

    public func matchingRule(for path: String) async throws -> IgnoreMatch? {
        let output = try await executor.run(["check-ignore", "-v", "-z", "--no-index", "--stdin"], input: path + "\0", kind: .read, allowedExitCodes: [0, 1])
        let fields = output.split(separator: "\0", omittingEmptySubsequences: false)
        guard fields.count >= 3, let line = Int(fields[1]) else { return nil }
        return IgnoreMatch(source: String(fields[0]), line: line, pattern: String(fields[2]))
    }

    private func location(of target: IgnoreTarget) async throws -> URL {
        switch target {
        case .gitignore:
            let root = try await executor.read(["rev-parse", "--show-toplevel"]).trimmingCharacters(in: .newlines)
            return URL(fileURLWithPath: root).appendingPathComponent(".gitignore")
        case .exclude:
            let path = try await executor.read(["rev-parse", "--path-format=absolute", "--git-path", "info/exclude"]).trimmingCharacters(in: .newlines)
            return URL(fileURLWithPath: path)
        }
    }
}
