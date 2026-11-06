import MorkDomain
import Foundation

public final class RepositoryClonerImpl: RepositoryClonerProtocol {
    private let makeExecutor: @Sendable (URL) -> GitStreamingCommandExecuting

    public init(makeExecutor: @escaping @Sendable (URL) -> GitStreamingCommandExecuting) {
        self.makeExecutor = makeExecutor
    }

    public func isAvailableDestination(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else { return true }
        guard isDirectory.boolValue else { return false }
        return (try? FileManager.default.contentsOfDirectory(atPath: url.path).isEmpty) ?? false
    }

    public func clone(from source: String, to destination: URL, progress: @escaping @Sendable (String) -> Void) async throws {
        let parent = destination.deletingLastPathComponent()
        let existed = FileManager.default.fileExists(atPath: destination.path)
        let removable = isAvailableDestination(destination)
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        do {
            _ = try await makeExecutor(parent).run(["clone", "--progress", source, destination.path], kind: .write, allowedExitCodes: [0], onProgress: progress)
        } catch {
            if removable { removePartialClone(at: destination, keepingFolder: existed) }
            throw error
        }
    }

    private func removePartialClone(at destination: URL, keepingFolder: Bool) {
        let manager = FileManager.default
        guard keepingFolder else {
            try? manager.removeItem(at: destination)
            return
        }
        for item in (try? manager.contentsOfDirectory(at: destination, includingPropertiesForKeys: nil)) ?? [] {
            try? manager.removeItem(at: item)
        }
    }
}
