import Foundation

public struct DiscoveredRepository: Hashable, Sendable {
    public enum Kind: Hashable, Sendable {
        case workingCopy
        case bare
        case linkedWorktree(main: URL)
        case submodule(parent: URL)
    }

    public let url: URL
    public let kind: Kind
    public let lastActivity: Date?

    public init(url: URL, kind: Kind = .workingCopy, lastActivity: Date? = nil) {
        self.url = url
        self.kind = kind
        self.lastActivity = lastActivity
    }

    public var name: String { url.lastPathComponent }
    public var isBare: Bool { kind == .bare }

    public var mainRepository: URL? {
        if case let .linkedWorktree(main) = kind { return main }
        return nil
    }
}

public struct RepositoryScan: Equatable, Sendable {
    public let folder: URL
    public let repositories: [DiscoveredRepository]
    public let unreadable: [URL]

    public init(folder: URL, repositories: [DiscoveredRepository], unreadable: [URL] = []) {
        self.folder = folder
        self.repositories = repositories
        self.unreadable = unreadable
    }
}

public struct RepositoryStatusSummary: Equatable, Sendable {
    public let branch: String
    public let isDirty: Bool

    public init(branch: String, isDirty: Bool) {
        self.branch = branch
        self.isDirty = isDirty
    }
}

public struct RepositoryGroup: Identifiable, Equatable, Sendable {
    public let title: String
    public let folder: URL?
    public let repositories: [DiscoveredRepository]

    public init(title: String, folder: URL?, repositories: [DiscoveredRepository]) {
        self.title = title
        self.folder = folder
        self.repositories = repositories
    }

    public var id: String { folder.map { "folder:\($0.path)" } ?? "recent" }
}

public enum RepositoryScanRules {
    public static let maxDepth = 4
    public static let skippedFolderNames: Set<String> = ["node_modules", ".build", "Pods", "DerivedData"]

    private static let gitDirPrefix = "gitdir:"
    private static let bareMarkers: Set<String> = ["HEAD", "objects", "refs"]

    public static func shouldDescend(into name: String) -> Bool {
        !skippedFolderNames.contains(name) && !name.hasPrefix(".")
    }

    public static func isBareRepository(entries: Set<String>) -> Bool {
        bareMarkers.isSubset(of: entries) && !entries.contains(".git")
    }

    public static func gitDirectory(fromGitFile contents: String, in directory: URL) -> URL? {
        guard let line = contents.split(whereSeparator: \.isNewline).first, line.hasPrefix(gitDirPrefix) else { return nil }
        let path = line.dropFirst(gitDirPrefix.count).trimmingCharacters(in: .whitespaces)
        guard !path.isEmpty else { return nil }
        let resolved = path.hasPrefix("/") ? URL(filePath: path, directoryHint: .notDirectory) : directory.appendingPathComponent(path)
        return URL(filePath: resolved.standardizedFileURL.path, directoryHint: .notDirectory)
    }

    public static func kind(forGitDirectory gitDirectory: URL) -> DiscoveredRepository.Kind {
        let components = gitDirectory.standardizedFileURL.pathComponents
        for marker in ["worktrees", "modules"] {
            guard let index = components.lastIndex(of: marker), index > 1, components[index - 1] == ".git" else { continue }
            let owner = URL(filePath: NSString.path(withComponents: Array(components[..<(index - 1)])), directoryHint: .notDirectory)
            return marker == "worktrees" ? .linkedWorktree(main: owner) : .submodule(parent: owner)
        }
        return .workingCopy
    }

    public static func mainRepository(forCommonDirectory commonDirectory: URL) -> URL? {
        let standardized = commonDirectory.standardizedFileURL
        guard standardized.lastPathComponent == ".git" else { return nil }
        return URL(filePath: standardized.deletingLastPathComponent().path, directoryHint: .notDirectory)
    }
}

public enum RepositoryManagerCatalog {
    public static let recentTitle = "Recent"

    public static func groups(scans: [RepositoryScan], recents: [URL]) -> [RepositoryGroup] {
        var known: [String: DiscoveredRepository] = [:]
        for repository in scans.flatMap(\.repositories) {
            known[canonicalPath(repository.url)] = repository
        }
        var groups: [RepositoryGroup] = []
        if !recents.isEmpty {
            let repositories = recents.map { known[canonicalPath($0)] ?? DiscoveredRepository(url: $0) }
            groups.append(RepositoryGroup(title: recentTitle, folder: nil, repositories: unique(repositories)))
        }
        for scan in scans {
            groups.append(RepositoryGroup(title: scan.folder.lastPathComponent, folder: scan.folder, repositories: sorted(folded(unique(scan.repositories)), recents: recents)))
        }
        return groups
    }

    public static func openableRepositories(in scans: [RepositoryScan]) -> [DiscoveredRepository] {
        folded(unique(scans.flatMap(\.repositories))).filter { !$0.isBare }
    }

    public static func sorted(_ repositories: [DiscoveredRepository], recents: [URL]) -> [DiscoveredRepository] {
        var recentRank: [String: Int] = [:]
        for (index, url) in recents.enumerated() where recentRank[canonicalPath(url)] == nil {
            recentRank[canonicalPath(url)] = index
        }
        return repositories.sorted { lhs, rhs in
            let left = recentRank[canonicalPath(lhs.url)]
            let right = recentRank[canonicalPath(rhs.url)]
            if left != right {
                guard let left else { return false }
                guard let right else { return true }
                return left < right
            }
            if lhs.lastActivity != rhs.lastActivity {
                guard let leftDate = lhs.lastActivity else { return false }
                guard let rightDate = rhs.lastActivity else { return true }
                return leftDate > rightDate
            }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
    }

    static func canonicalPath(_ url: URL) -> String {
        RecentRepositoryList.canonical(url).path
    }

    private static func unique(_ repositories: [DiscoveredRepository]) -> [DiscoveredRepository] {
        var seen: Set<String> = []
        return repositories.filter { seen.insert(canonicalPath($0.url)).inserted }
    }

    private static func folded(_ repositories: [DiscoveredRepository]) -> [DiscoveredRepository] {
        let paths = Set(repositories.map { canonicalPath($0.url) })
        return repositories.filter { repository in
            guard let main = repository.mainRepository else { return true }
            return !paths.contains(canonicalPath(main))
        }
    }
}
