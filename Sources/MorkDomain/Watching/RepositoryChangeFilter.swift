import Foundation

public enum RepositoryChangeFilter {
    private static let ignoredGitPrefixes = [".git/objects", ".git/logs", ".git/worktrees/", ".git/fsmonitor--daemon"]
    private static let ignoredModuleFolders: Set<Substring> = ["objects", "logs", "worktrees"]
    private static let modulesPrefix = ".git/modules/"
    private static let ignoredNames: Set<String> = [".DS_Store", "4913"]
    private static let ignoredSuffixes = [".swp", ".swo", ".swx", "~", ".tmp", "___jb_tmp___", "___jb_old___"]

    public static func containsRelevantChange(_ paths: [String]) -> Bool {
        paths.contains(where: isRelevant)
    }

    public static func isRelevant(_ path: String) -> Bool {
        if path.hasPrefix(".git/") {
            return !path.hasSuffix(".lock") && !ignoredGitPrefixes.contains { path.hasPrefix($0) } && !isModuleNoise(path)
        }
        let name = path.split(separator: "/").last.map(String.init) ?? path
        if ignoredNames.contains(name) || name.hasPrefix(".#") { return false }
        return !ignoredSuffixes.contains { name.hasSuffix($0) }
    }

    public static func needsIgnoreCheck(_ path: String) -> Bool {
        !path.isEmpty && path != ".git" && !path.hasPrefix(".git/")
    }

    private static func isModuleNoise(_ path: String) -> Bool {
        guard path.hasPrefix(modulesPrefix) else { return false }
        let folders = path.dropFirst(modulesPrefix.count).split(separator: "/").dropFirst().prefix { $0 != "refs" }
        return folders.contains { ignoredModuleFolders.contains($0) || $0.hasPrefix("fsmonitor--daemon") }
    }
}
