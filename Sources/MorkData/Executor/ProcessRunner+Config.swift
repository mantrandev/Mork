import Foundation

extension ProcessRunner {
    static func configEnvironment(_ entries: [(String, String)], inheriting base: [String: String] = ProcessInfo.processInfo.environment) -> [String: String] {
        let inherited = Int(base["GIT_CONFIG_COUNT"] ?? "").map { max($0, 0) } ?? 0
        let start = inherited + configEntries.count
        var result: [String: String] = [:]
        for (offset, entry) in entries.enumerated() {
            result["GIT_CONFIG_KEY_\(start + offset)"] = entry.0
            result["GIT_CONFIG_VALUE_\(start + offset)"] = entry.1
        }
        result["GIT_CONFIG_COUNT"] = String(start + entries.count)
        return result
    }
}
