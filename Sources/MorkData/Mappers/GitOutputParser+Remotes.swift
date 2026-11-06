import MorkDomain
import Foundation

extension GitOutputParser {
    private static let fetchSuffix = " (fetch)"
    private static let pushSuffix = " (push)"

    static func remotes(_ output: String) -> [Remote] {
        var order: [String] = []
        var fetchURLs: [String: String] = [:]
        var pushURLs: [String: String] = [:]
        for line in output.split(separator: "\n") {
            guard let tab = line.firstIndex(of: "\t") else { continue }
            let name = String(line[..<tab])
            let rest = String(line[line.index(after: tab)...])
            if rest.hasSuffix(fetchSuffix), fetchURLs[name] == nil {
                fetchURLs[name] = String(rest.dropLast(fetchSuffix.count))
                order.append(name)
            } else if rest.hasSuffix(pushSuffix), pushURLs[name] == nil {
                pushURLs[name] = String(rest.dropLast(pushSuffix.count))
            }
        }
        return order.compactMap { name in
            guard let fetchURL = fetchURLs[name] else { return nil }
            let pushURL = pushURLs[name]
            return Remote(name: name, fetchURL: fetchURL, pushURL: pushURL == fetchURL ? nil : pushURL)
        }
    }
}
