import MorkDomain
import Foundation

public final class PatchRepositoryImpl: PatchRepositoryProtocol {
    private let executor: GitCommandExecuting

    public init(executor: GitCommandExecuting) {
        self.executor = executor
    }

    public func readPatch(at file: URL) async throws -> String {
        LosslessText.decode(try Data(contentsOf: file))
    }

    public func check(patchAt file: URL, mode: PatchApplyMode) async throws {
        let target = switch mode {
        case .workingTree: [String]()
        case .index: ["--cached"]
        case .mailbox: ["--index"]
        }
        try await executor.read(["apply", "--check"] + target + [file.path])
    }

    public func apply(patchAt file: URL, mode: PatchApplyMode) async throws {
        switch mode {
        case .workingTree:
            try await executor.write(["apply", file.path])
        case .index:
            try await executor.write(["apply", "--cached", file.path])
        case .mailbox:
            do {
                try await executor.write(["am", file.path])
            } catch {
                _ = try? await executor.write(["am", "--abort"], allowedExitCodes: nil)
                throw error
            }
        }
    }

    public func export(_ commit: Commit, to destination: URL) async throws {
        let patch = try await executor.runData(["format-patch", "-1", commit.hash, "--stdout"], kind: .read, allowedExitCodes: [0])
        try patch.write(to: destination, options: .atomic)
    }
}
