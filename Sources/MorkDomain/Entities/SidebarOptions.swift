import Foundation

public struct SidebarOptions: Codable, Hashable, Sendable {
    public var tagSortOrder: TagSortOrder
    public var branchSortOrder: BranchSortOrder
    public var remoteBranchSortOrder: BranchSortOrder
    public var recentlyUsedBranches: [String]
    public var recentlyUsedRemoteBranches: [String]

    public init(
        tagSortOrder: TagSortOrder = .recentlyUsed,
        branchSortOrder: BranchSortOrder = .alphabeticalMainAndFoldersFirst,
        remoteBranchSortOrder: BranchSortOrder = .alphabeticalMainAndFoldersFirst,
        recentlyUsedBranches: [String] = [],
        recentlyUsedRemoteBranches: [String] = []
    ) {
        self.tagSortOrder = tagSortOrder
        self.branchSortOrder = branchSortOrder
        self.remoteBranchSortOrder = remoteBranchSortOrder
        self.recentlyUsedBranches = recentlyUsedBranches
        self.recentlyUsedRemoteBranches = recentlyUsedRemoteBranches
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            tagSortOrder: try values.decodeIfPresent(TagSortOrder.self, forKey: .tagSortOrder) ?? .recentlyUsed,
            branchSortOrder: try values.decodeIfPresent(BranchSortOrder.self, forKey: .branchSortOrder) ?? .alphabeticalMainAndFoldersFirst,
            remoteBranchSortOrder: try values.decodeIfPresent(BranchSortOrder.self, forKey: .remoteBranchSortOrder) ?? .alphabeticalMainAndFoldersFirst,
            recentlyUsedBranches: try values.decodeIfPresent([String].self, forKey: .recentlyUsedBranches) ?? [],
            recentlyUsedRemoteBranches: try values.decodeIfPresent([String].self, forKey: .recentlyUsedRemoteBranches) ?? []
        )
    }

    public static let standard = SidebarOptions()
}
