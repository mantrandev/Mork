import Foundation

public enum RecentRepositoryList {
    public static let limit = 10

    public static func adding(_ url: URL, to list: [URL]) -> [URL] {
        normalized([url] + list)
    }

    public static func normalized(_ list: [URL]) -> [URL] {
        var seen: Set<String> = []
        var result: [URL] = []
        for url in list.map(canonical) where seen.insert(url.path).inserted {
            result.append(url)
            if result.count == limit { break }
        }
        return result
    }

    static func canonical(_ url: URL) -> URL {
        URL(filePath: url.standardizedFileURL.path, directoryHint: .notDirectory)
    }
}
