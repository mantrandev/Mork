import Foundation

public enum RepositoryChangeFilter {
    private static let ignoredGitPrefixes = [".git/objects", ".git/logs", ".git/worktrees/"]
    private static let ignoredNames: Set<String> = [".DS_Store", "4913"]
    private static let ignoredSuffixes = [".swp", ".swo", ".swx", "~", ".tmp", "___jb_tmp___", "___jb_old___"]

    public static func containsRelevantChange(_ paths: [String]) -> Bool {
        paths.contains(where: isRelevant)
    }

    public static func isRelevant(_ path: String) -> Bool {
        if path.hasPrefix(".git/") {
            return !path.hasSuffix(".lock") && !ignoredGitPrefixes.contains { path.hasPrefix($0) }
        }
        let name = path.split(separator: "/").last.map(String.init) ?? path
        if ignoredNames.contains(name) || name.hasPrefix(".#") { return false }
        return !ignoredSuffixes.contains { name.hasSuffix($0) }
    }
}
