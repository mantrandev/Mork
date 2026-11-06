import MorkDomain
import Foundation

public final class ConflictRepositoryImpl: ConflictRepositoryProtocol {
    private static let literalPathspecs = "--literal-pathspecs"
    private static let mergeFileExitCodes = Set<Int32>(0...127)
    private static let merges = SerialQueue()

    private let executor: GitCommandExecuting
    private let root: URL

    public init(executor: GitCommandExecuting, root: URL) {
        self.executor = executor
        self.root = root
    }

    public func contents(of path: String) async throws -> Data? {
        let file = url(of: path)
        guard FileManager.default.fileExists(atPath: file.path) else { return nil }
        return try Data(contentsOf: file)
    }

    public func stage(_ stage: ConflictStage, of path: String) async throws -> Data {
        try await executor.runData(["show", stage.revision(of: path)], kind: .read, allowedExitCodes: [0])
    }

    public func mergeFile(_ input: ConflictMergeInput, style: ConflictMarkerStyle) async throws -> Data {
        try await Self.merges.run { [executor] in
            let folder = FileManager.default.temporaryDirectory
                .appendingPathComponent("mork-merge", isDirectory: true)
                .appendingPathComponent(input.name, isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: folder) }
            let files = [("ours", input.ours), ("base", input.base), ("theirs", input.theirs)].map { name, data in
                (url: folder.appendingPathComponent(name), data: data)
            }
            for file in files {
                try file.data.write(to: file.url)
            }
            let styleFlags = style == .zdiff3 ? ["--zdiff3"] : ["--no-diff3"]
            let arguments = ["merge-file", "-p"] + styleFlags + ["--diff-algorithm=histogram", "-L", input.oursLabel, "-L", input.baseLabel, "-L", input.theirsLabel] + files.map(\.url.path)
            return try await executor.runData(arguments, kind: .read, allowedExitCodes: Self.mergeFileExitCodes)
        }
    }

    public func saveResolution(_ content: String, to path: String) async throws {
        try write(Data(content.utf8), to: url(of: path))
        try await markResolved(path: path)
    }

    public func checkout(_ side: ConflictSide, path: String) async throws {
        try await executor.write([Self.literalPathspecs, "checkout", side.checkoutFlag, "--", path])
    }

    public func markResolved(path: String) async throws {
        try await executor.write([Self.literalPathspecs, "add", "--", path])
    }

    public func remove(path: String) async throws {
        try await executor.write([Self.literalPathspecs, "rm", "--quiet", "--", path])
    }

    public func concludeMerge() async throws {
        try await executor.write(["commit", "--no-edit"])
    }

    private func url(of path: String) -> URL {
        root.appendingPathComponent(path)
    }

    private func write(_ data: Data, to file: URL) throws {
        guard FileManager.default.fileExists(atPath: file.path) else {
            try data.write(to: file)
            return
        }
        let handle = try FileHandle(forWritingTo: file)
        defer { try? handle.close() }
        try handle.truncate(atOffset: 0)
        try handle.write(contentsOf: data)
    }
}

private actor SerialQueue {
    private var tail: Task<Void, Never>?

    func run<T: Sendable>(_ body: @escaping @Sendable () async throws -> T) async throws -> T {
        let previous = tail
        let task = Task {
            await previous?.value
            return try await body()
        }
        tail = Task { _ = try? await task.value }
        return try await task.value
    }
}
