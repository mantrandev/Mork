import MorkDomain
import Foundation

public struct CommandLineToolRepositoryImpl: CommandLineToolRepositoryProtocol {
    public struct Folder: Equatable, Sendable {
        public let url: URL
        public let isOnDefaultPath: Bool

        public init(url: URL, isOnDefaultPath: Bool) {
            self.url = url
            self.isOnDefaultPath = isOnDefaultPath
        }
    }

    private let script: URL?
    private let name: String
    private let folders: [Folder]
    private let fallback: Folder

    public init(script: URL?, name: String, folders: [Folder], fallback: Folder) {
        self.script = script
        self.name = name
        self.folders = folders
        self.fallback = fallback
    }

    public static func standard(script: URL?, name: String, home: URL = FileManager.default.homeDirectoryForCurrentUser) -> CommandLineToolRepositoryImpl {
        CommandLineToolRepositoryImpl(
            script: script,
            name: name,
            folders: [
                Folder(url: URL(fileURLWithPath: "/opt/homebrew/bin", isDirectory: true), isOnDefaultPath: true),
                Folder(url: URL(fileURLWithPath: "/usr/local/bin", isDirectory: true), isOnDefaultPath: true)
            ],
            fallback: Folder(url: home.appendingPathComponent(".local/bin", isDirectory: true), isOnDefaultPath: false)
        )
    }

    public func status() -> CommandLineToolStatus {
        guard let script = existingScript else { return .unavailable }
        for folder in folders + [fallback] where points(link(in: folder), to: script) {
            return installed(in: folder)
        }
        return .notInstalled(name: name)
    }

    public func install() throws -> CommandLineToolStatus {
        guard let script = existingScript else { throw CommandLineToolError.unavailable }
        if case .installed = status() { return status() }
        let manager = FileManager.default
        let folder = folders.first { isWritableFolder($0.url) } ?? fallback
        if folder == fallback {
            try? manager.createDirectory(at: fallback.url, withIntermediateDirectories: true)
            guard isWritableFolder(fallback.url) else { throw CommandLineToolError.notWritable }
        }
        let link = link(in: folder)
        if (try? manager.destinationOfSymbolicLink(atPath: link.path)) != nil {
            try manager.removeItem(at: link)
        } else if manager.fileExists(atPath: link.path) {
            throw CommandLineToolError.occupied(path: link.path)
        }
        try manager.createSymbolicLink(at: link, withDestinationURL: script)
        return installed(in: folder)
    }

    private var existingScript: URL? {
        guard let script, FileManager.default.isExecutableFile(atPath: script.path) else { return nil }
        return script
    }

    private func link(in folder: Folder) -> URL {
        folder.url.appendingPathComponent(name)
    }

    private func installed(in folder: Folder) -> CommandLineToolStatus {
        .installed(name: name, path: link(in: folder).path, needsPathEntry: !folder.isOnDefaultPath)
    }

    private func points(_ link: URL, to script: URL) -> Bool {
        guard let destination = try? FileManager.default.destinationOfSymbolicLink(atPath: link.path) else { return false }
        let resolved = URL(fileURLWithPath: destination, relativeTo: link.deletingLastPathComponent())
        return resolved.standardizedFileURL.resolvingSymlinksInPath().path == script.standardizedFileURL.resolvingSymlinksInPath().path
    }

    private func isWritableFolder(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue && FileManager.default.isWritableFile(atPath: url.path)
    }
}
