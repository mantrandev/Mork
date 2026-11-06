import MorkDomain
import Foundation

public final class ExternalToolRepositoryImpl: ExternalToolRepositoryProtocol {
    private let executor: GitToolCommandExecuting
    private let root: URL

    public init(executor: GitToolCommandExecuting, root: URL) {
        self.executor = executor
        self.root = root
    }

    public func runMergeTool(_ launch: ExternalToolLaunch, trustsExitCode: Bool, path: String) async throws -> ExternalToolExit {
        let existing = Set(leftovers(of: path).map(\.file))
        let exit: ExternalToolExit
        do {
            exit = try await executor.runTool(ExternalToolCommand.merge(launch, trustsExitCode: trustsExitCode, path: path), kind: .write)
        } catch is CancellationError {
            restoreLeftovers(of: path, keeping: existing)
            throw CancellationError()
        }
        if exit.exitCode != 0 { restoreLeftovers(of: path, keeping: existing) }
        return exit
    }

    public func runDiffTool(_ launch: ExternalToolLaunch, target: ExternalDiffTarget, path: String) async throws -> ExternalToolExit {
        let emptyTree = target.isRootCommit
            ? try await executor.read(["hash-object", "-t", "tree", "/dev/null"]).trimmingCharacters(in: .whitespacesAndNewlines)
            : ""
        return try await executor.runTool(ExternalToolCommand.diff(launch, revisions: target.revisions(emptyTree: emptyTree), path: path), kind: .read)
    }

    private func restoreLeftovers(of path: String, keeping existing: Set<URL>) {
        let merged = root.appendingPathComponent(path)
        for (file, isBackup) in leftovers(of: path) where !existing.contains(file) {
            if isBackup {
                try? FileManager.default.removeItem(at: merged)
                try? FileManager.default.moveItem(at: file, to: merged)
            } else {
                try? FileManager.default.removeItem(at: file)
            }
        }
    }

    private func leftovers(of path: String) -> [(file: URL, isBackup: Bool)] {
        let merged = root.appendingPathComponent(path)
        let name = merged.lastPathComponent
        let split = name.lastIndex(of: ".") ?? name.endIndex
        let pattern = "^\(NSRegularExpression.escapedPattern(for: String(name[..<split])))_(BACKUP|BASE|LOCAL|REMOTE)_[0-9]+\(NSRegularExpression.escapedPattern(for: String(name[split...])))$"
        guard let expression = try? NSRegularExpression(pattern: pattern),
              let files = try? FileManager.default.contentsOfDirectory(at: merged.deletingLastPathComponent(), includingPropertiesForKeys: nil)
        else { return [] }
        return files.compactMap { file in
            let fileName = file.lastPathComponent
            guard let match = expression.firstMatch(in: fileName, range: NSRange(fileName.startIndex..., in: fileName)),
                  let kind = Range(match.range(at: 1), in: fileName).map({ fileName[$0] })
            else { return nil }
            return (file, kind == "BACKUP")
        }
    }
}
