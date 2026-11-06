import Foundation

struct BranchFolderSuggestion: Hashable {
    let folder: String
    let matchedCount: Int
    let branchCount: Int

    var matched: String { String(folder.prefix(matchedCount)) }
    var rest: String { String(folder.dropFirst(matchedCount)) }
    var countTitle: String { branchCount == 1 ? "1 branch" : "\(branchCount) branches" }

    static func suggestions(for input: String, branchNames: [String]) -> [BranchFolderSuggestion] {
        BranchNameInput.suggestions(for: input, branchNames: branchNames).map { folder in
            BranchFolderSuggestion(
                folder: folder,
                matchedCount: input.count,
                branchCount: branchNames.reduce(0) { $0 + ($1.hasPrefix(folder) ? 1 : 0) }
            )
        }
    }
}
