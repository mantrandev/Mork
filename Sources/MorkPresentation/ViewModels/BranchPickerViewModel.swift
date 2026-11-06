import MorkDomain
import Foundation
import Observation

struct BranchPickerItem: Identifiable, Equatable {
    enum Kind: Equatable {
        case branch(Branch)
        case worktree(WorktreeRow)
    }

    let kind: Kind
    let highlights: [Range<Int>]

    var id: String {
        switch kind {
        case let .branch(branch): "branch:\(branch.fullName)"
        case let .worktree(row): "worktree:\(row.worktree.path)"
        }
    }

    var isEnabled: Bool {
        guard case let .worktree(row) = kind else { return true }
        return !row.worktree.isPrunable
    }
}

@MainActor
@Observable
final class BranchPickerViewModel {
    static let backgroundThreshold = QuickLaunchViewModel.backgroundThreshold

    var query = "" {
        didSet { if query != oldValue { updateResults() } }
    }
    private(set) var branches: [BranchPickerItem] = []
    private(set) var worktrees: [BranchPickerItem] = []
    private(set) var selectedIndex = 0
    private(set) var revision = 0

    @ObservationIgnored private let allBranches: [Branch]
    @ObservationIgnored private let allWorktrees: [WorktreeRow]
    @ObservationIgnored private let branchNames: [String]
    @ObservationIgnored private let worktreeTitles: [String]
    @ObservationIgnored private var rankTask: Task<Void, Never>?
    @ObservationIgnored private var generation = 0

    init(branches: [Branch], worktrees: [WorktreeRow]) {
        allBranches = branches
        allWorktrees = worktrees
        branchNames = branches.map(\.name)
        worktreeTitles = worktrees.map { Self.title(of: $0.worktree) }
        updateResults()
        selectedIndex = branches.firstIndex(where: \.isCurrent) ?? 0
    }

    var count: Int { branches.count + worktrees.count }

    func item(at index: Int) -> BranchPickerItem? {
        if branches.indices.contains(index) { return branches[index] }
        let worktreeIndex = index - branches.count
        return worktrees.indices.contains(worktreeIndex) ? worktrees[worktreeIndex] : nil
    }

    var selectedItem: BranchPickerItem? { item(at: selectedIndex) }
    var selectedID: String? { selectedItem?.id }

    func moveSelection(by offset: Int) {
        guard count > 0 else { return }
        selectedIndex = min(max(selectedIndex + offset, 0), count - 1)
    }

    func select(_ item: BranchPickerItem) {
        if let index = branches.firstIndex(of: item) {
            selectedIndex = index
        } else if let index = worktrees.firstIndex(of: item) {
            selectedIndex = branches.count + index
        }
    }

    func waitForResults() async {
        await rankTask?.value
    }

    static func title(of worktree: Worktree) -> String {
        let detail = worktree.isPrunable ? "missing" : worktree.branch ?? worktree.shortHead.map { "detached at \($0)" } ?? ""
        return detail.isEmpty ? worktree.name : "\(worktree.name) — \(detail)"
    }

    private func updateResults() {
        generation += 1
        rankTask?.cancel()
        rankTask = nil
        let text = query
        guard !text.allSatisfy(\.isWhitespace) else {
            apply(
                branches: allBranches.indices.map { FuzzyRanked(index: $0, match: FuzzyMatch(score: 0, ranges: [])) },
                worktrees: allWorktrees.indices.map { FuzzyRanked(index: $0, match: FuzzyMatch(score: 0, ranges: [])) }
            )
            return
        }
        let names = branchNames
        let titles = worktreeTitles
        guard names.count + titles.count > Self.backgroundThreshold else {
            apply(branches: FuzzyMatcher.rank(names, query: text, limit: names.count), worktrees: FuzzyMatcher.rank(titles, query: text, limit: titles.count))
            return
        }
        let current = generation
        rankTask = Task { [weak self] in
            let ranked = await Task.detached(priority: .userInitiated) {
                (FuzzyMatcher.rank(names, query: text, limit: names.count), FuzzyMatcher.rank(titles, query: text, limit: titles.count))
            }.value
            guard let self, !Task.isCancelled, generation == current else { return }
            apply(branches: ranked.0, worktrees: ranked.1)
        }
    }

    private func apply(branches rankedBranches: [FuzzyRanked], worktrees rankedWorktrees: [FuzzyRanked]) {
        branches = rankedBranches.map { BranchPickerItem(kind: .branch(allBranches[$0.index]), highlights: $0.match.ranges) }
        worktrees = rankedWorktrees.map { BranchPickerItem(kind: .worktree(allWorktrees[$0.index]), highlights: $0.match.ranges) }
        selectedIndex = 0
        revision += 1
    }
}
