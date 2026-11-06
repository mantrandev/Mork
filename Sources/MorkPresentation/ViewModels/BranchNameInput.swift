import Foundation

enum BranchNameInput {
    static func normalized(_ name: String) -> String {
        name.replacingOccurrences(of: " ", with: "-")
    }

    static func suggestions(for input: String, branchNames: [String]) -> [String] {
        guard !input.isEmpty else { return [] }
        let folders = Set(branchNames.flatMap { name -> [String] in
            let parts = name.split(separator: "/")
            return (1..<max(1, parts.count)).map { parts.prefix($0).joined(separator: "/") + "/" }
        })
        return folders.filter {
            $0.count > input.count && $0.lowercased().hasPrefix(input.lowercased())
        }.sorted()
    }
}
