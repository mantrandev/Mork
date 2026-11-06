import MorkDomain
import Foundation

public final class FileSystemRepositoryScannerImpl: RepositoryScannerProtocol {
    private static let resourceKeys: Set<URLResourceKey> = [.isDirectoryKey, .isSymbolicLinkKey]

    public init() {}

    public func scan(folder: URL, maxDepth: Int) async -> RepositoryScan {
        await withCheckedContinuation { continuation in
            DispatchQueue(label: "dev.mantrandev.mork.repository-scan", qos: .userInitiated).async {
                continuation.resume(returning: Self.scanSynchronously(folder: folder, maxDepth: maxDepth))
            }
        }
    }

    private static func scanSynchronously(folder: URL, maxDepth: Int) -> RepositoryScan {
        let manager = FileManager.default
        var visited: Set<String> = []
        var found: [String: DiscoveredRepository] = [:]
        var unreadable: [URL] = []
        var pending: [(url: URL, depth: Int)] = [(normalized(folder), 0)]
        while let (directory, depth) = pending.popLast() {
            guard visited.insert(directory.path).inserted else { continue }
            let entries: [URL]
            do {
                entries = try manager.contentsOfDirectory(at: directory, includingPropertiesForKeys: Array(resourceKeys), options: [])
            } catch {
                unreadable.append(directory)
                continue
            }
            let names = Set(entries.map(\.lastPathComponent))
            if let repository = repository(at: directory, names: names) {
                found[directory.path] = found[directory.path] ?? repository
                continue
            }
            guard depth < maxDepth else { continue }
            for entry in entries where RepositoryScanRules.shouldDescend(into: entry.lastPathComponent) {
                if let child = childDirectory(entry, in: directory) {
                    pending.append((child, depth + 1))
                }
            }
        }
        let repositories = found.values.sorted { $0.url.path < $1.url.path }
        return RepositoryScan(folder: folder, repositories: repositories, unreadable: unreadable)
    }

    private static func childDirectory(_ entry: URL, in directory: URL) -> URL? {
        guard let values = try? entry.resourceValues(forKeys: resourceKeys) else { return nil }
        if values.isSymbolicLink == true {
            let target = normalized(entry)
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: target.path, isDirectory: &isDirectory), isDirectory.boolValue else { return nil }
            return target
        }
        guard values.isDirectory == true else { return nil }
        return URL(filePath: directory.path + "/" + entry.lastPathComponent, directoryHint: .notDirectory)
    }

    private static func normalized(_ url: URL) -> URL {
        URL(filePath: url.resolvingSymlinksInPath().path, directoryHint: .notDirectory)
    }

    private static func repository(at directory: URL, names: Set<String>) -> DiscoveredRepository? {
        if names.contains(".git") {
            let marker = directory.appendingPathComponent(".git")
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: marker.path, isDirectory: &isDirectory) else { return nil }
            if isDirectory.boolValue {
                return DiscoveredRepository(url: directory, kind: .workingCopy, lastActivity: activity(in: marker))
            }
            guard let contents = try? String(contentsOf: marker, encoding: .utf8),
                  let gitDirectory = RepositoryScanRules.gitDirectory(fromGitFile: contents, in: directory) else { return nil }
            let resolvedGitDirectory = normalized(gitDirectory)
            return DiscoveredRepository(url: directory, kind: RepositoryScanRules.kind(forGitDirectory: resolvedGitDirectory), lastActivity: activity(in: resolvedGitDirectory))
        }
        guard RepositoryScanRules.isBareRepository(entries: names) else { return nil }
        return DiscoveredRepository(url: directory, kind: .bare, lastActivity: activity(in: directory))
    }

    private static func activity(in gitDirectory: URL) -> Date? {
        ["logs/HEAD", "index", "HEAD"]
            .compactMap { try? gitDirectory.appendingPathComponent($0).resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate }
            .max()
    }
}
