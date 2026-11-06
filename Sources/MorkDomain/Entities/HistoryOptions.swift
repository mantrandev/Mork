import Foundation

public struct HistoryOptions: Codable, Hashable, Sendable {
    private static let tagPrefix = "tag: "

    public var hidesTags: Bool
    public var showsLostCommits: Bool
    public var firstParentOnly: Bool
    public var currentBranchOnly: Bool
    public var hidesStashes: Bool
    public var pinnedBranches: [String]
    public var filteredBranches: [String]
    public var filteredBranch: String? {
        get { filteredBranches.first }
        set { filteredBranches = newValue.map { [$0] } ?? [] }
    }
    public var hiddenBranches: [String]

    public init(
        hidesTags: Bool = false,
        showsLostCommits: Bool = false,
        firstParentOnly: Bool = false,
        currentBranchOnly: Bool = false,
        hidesStashes: Bool = true,
        pinnedBranches: [String] = [],
        filteredBranch: String? = nil,
        hiddenBranches: [String] = [],
        filteredBranches: [String]? = nil
    ) {
        self.hidesTags = hidesTags
        self.showsLostCommits = showsLostCommits
        self.firstParentOnly = firstParentOnly
        self.currentBranchOnly = currentBranchOnly
        self.hidesStashes = hidesStashes
        self.pinnedBranches = pinnedBranches
        self.filteredBranches = filteredBranches ?? filteredBranch.map { [$0] } ?? []
        self.hiddenBranches = hiddenBranches
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let standard = Self.standard
        let legacy = try decoder.container(keyedBy: LegacyCodingKeys.self)
        self.init(
            hidesTags: try container.decodeIfPresent(Bool.self, forKey: .hidesTags) ?? standard.hidesTags,
            showsLostCommits: try container.decodeIfPresent(Bool.self, forKey: .showsLostCommits) ?? standard.showsLostCommits,
            firstParentOnly: try container.decodeIfPresent(Bool.self, forKey: .firstParentOnly) ?? standard.firstParentOnly,
            currentBranchOnly: try container.decodeIfPresent(Bool.self, forKey: .currentBranchOnly) ?? standard.currentBranchOnly,
            hidesStashes: try container.decodeIfPresent(Bool.self, forKey: .hidesStashes) ?? standard.hidesStashes,
            pinnedBranches: try container.decodeIfPresent([String].self, forKey: .pinnedBranches) ?? standard.pinnedBranches,
            filteredBranch: try legacy.decodeIfPresent(String.self, forKey: .filteredBranch),
            hiddenBranches: try container.decodeIfPresent([String].self, forKey: .hiddenBranches) ?? standard.hiddenBranches,
            filteredBranches: try container.decodeIfPresent([String].self, forKey: .filteredBranches)
        )
    }

    public static let standard = HistoryOptions()

    private enum LegacyCodingKeys: String, CodingKey {
        case filteredBranch
    }

    public func isPinned(_ branch: Branch) -> Bool { pinnedBranches.contains(branch.fullName) }
    public func isHidden(_ branch: Branch) -> Bool { hiddenBranches.contains(branch.fullName) }
    public func isFiltered(to branch: Branch) -> Bool { filteredBranches.contains(branch.fullName) }

    public var revisionArguments: [String] {
        if !filteredBranches.isEmpty { return filteredBranches }
        if currentBranchOnly { return ["HEAD"] }
        return hiddenBranches.map { "--exclude=\($0)" } + ["--exclude=refs/stash", "--all"]
    }

    public var filteredBranchName: String? {
        filteredBranchNames.first
    }

    public var filteredBranchNames: [String] {
        filteredBranches.map(Self.branchName)
    }

    private static func branchName(_ reference: String) -> String {
        for prefix in ["refs/heads/", "refs/remotes/"] where reference.hasPrefix(prefix) {
            return String(reference.dropFirst(prefix.count))
        }
        return reference
    }

    public func renamingBranch(_ oldReference: String, to newReference: String) -> HistoryOptions {
        var options = self
        options.pinnedBranches = pinnedBranches.map { $0 == oldReference ? newReference : $0 }
        options.hiddenBranches = hiddenBranches.map { $0 == oldReference ? newReference : $0 }
        options.filteredBranches = filteredBranches.map { $0 == oldReference ? newReference : $0 }
        return options
    }

    public func visibleRefs(of commit: Commit) -> [String] {
        let hiddenNames = Set(hiddenBranches.map(Self.branchName))
        return commit.refNames.filter { ref in
            if ref.hasPrefix(Self.tagPrefix) { return !hidesTags }
            if StashHistory.isStashRef(ref) { return !hidesStashes }
            if ref == "HEAD" { return true }
            let headPrefix = "HEAD -> "
            let name = ref.hasPrefix(headPrefix) ? String(ref.dropFirst(headPrefix.count)) : ref
            return !hiddenNames.contains(name)
        }
    }
}
