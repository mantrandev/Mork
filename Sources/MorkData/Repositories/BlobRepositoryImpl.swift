import MorkDomain
import Foundation

public final class BlobRepositoryImpl: BlobRepositoryProtocol {
    private let executor: GitCommandExecuting
    private let root: URL

    public init(executor: GitCommandExecuting, root: URL) {
        self.executor = executor
        self.root = root
    }

    public func size(of blob: BlobReference) async throws -> Int {
        guard let object = blob.objectName else {
            let attributes = try FileManager.default.attributesOfItem(atPath: file(blob).path)
            return (attributes[.size] as? NSNumber)?.intValue ?? 0
        }
        let output = try await executor.read(["cat-file", "-s", object])
        return Int(output.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
    }

    public func data(of blob: BlobReference) async throws -> Data {
        guard let object = blob.objectName else {
            let url = file(blob)
            return try await Task.detached(priority: .userInitiated) { try Data(contentsOf: url) }.value
        }
        return try await executor.runData(["show", object], kind: .read, allowedExitCodes: [0])
    }

    public func export(_ blob: BlobReference, to destination: URL) async throws {
        let data = try await data(of: blob)
        try await Task.detached(priority: .userInitiated) {
            try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: destination, options: .atomic)
        }.value
    }

    private func file(_ blob: BlobReference) -> URL {
        root.appendingPathComponent(blob.path)
    }
}
