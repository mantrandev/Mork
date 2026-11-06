import MorkDomain
import Foundation
import Observation

public enum QuickLaunchCommand: String, CaseIterable, Sendable {
    case openRepository = "Open Repository…"
    case cloneRepository = "Clone…"
    case initializeRepository = "New Local Repository…"
    case addRepositoryFolder = "Add Folder to Repository Manager…"
    case rescanRepositoryFolders = "Rescan Repository Folders"
    case restoreClosedTab = "Restore Closed Tab"
    case closeTab = "Close Tab"
    case nextTab = "Show Next Tab"
    case previousTab = "Show Previous Tab"
    case fetch = "Fetch"
    case pull = "Pull"
    case push = "Push"
    case pullWithOptions = "Pull…"
    case pushWithOptions = "Push…"
    case newBranch = "New Branch…"
    case newTag = "New Tag…"
    case stash = "Stash…"
    case showChanges = "Show Uncommitted Changes"
    case showHistory = "Show All Commits"
    case showReflog = "Show Reflog"
    case refresh = "Refresh"
    case applyPatch = "Apply Patch…"
    case interactiveRebase = "Interactive Rebase…"
    case toggleConsole = "Show or Hide Git Console"
    case openTerminal = "Open in Terminal Tab"

    public var title: String { rawValue }
    public var choosesFolder: Bool { self == .openRepository || self == .initializeRepository }
}

public struct QuickLaunchItem: Identifiable, Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        case tab(URL)
        case recent(URL)
        case repository(URL)
        case branch(Branch)
        case tag(Tag)
        case command(QuickLaunchCommand)
        case customCommand(CustomCommand)
    }

    public let kind: Kind
    public let title: String
    public let subtitle: String

    public init(kind: Kind, title: String, subtitle: String) {
        self.kind = kind
        self.title = title
        self.subtitle = subtitle
    }

    public init(tab url: URL) {
        self.init(kind: .tab(url), title: url.lastPathComponent, subtitle: "Open tab · \(RecentLocation.title(for: url))")
    }

    public init(recent url: URL) {
        self.init(kind: .recent(url), title: url.lastPathComponent, subtitle: RecentLocation.title(for: url))
    }

    public init(repository url: URL) {
        self.init(kind: .repository(url), title: url.lastPathComponent, subtitle: "Repository Manager · \(RecentLocation.title(for: url))")
    }

    public init(branch: Branch) {
        self.init(kind: .branch(branch), title: branch.name, subtitle: branch.isRemote ? "Remote branch" : "Local branch")
    }

    public init(tag: Tag) {
        self.init(kind: .tag(tag), title: tag.name, subtitle: "Tag")
    }

    public init(customCommand: CustomCommand) {
        self.init(kind: .customCommand(customCommand), title: customCommand.name, subtitle: "Custom \(customCommand.kind == .git ? "git" : "shell") command · \(customCommand.commandLine)")
    }

    public init(command: QuickLaunchCommand, subtitle: String = "Command") {
        self.init(kind: .command(command), title: command.title, subtitle: subtitle)
    }

    public var id: String {
        switch kind {
        case let .tab(url): "tab:\(url.path)"
        case let .recent(url): "recent:\(url.path)"
        case let .repository(url): "repository:\(url.path)"
        case let .branch(branch): "branch:\(branch.fullName)"
        case let .tag(tag): "tag:\(tag.name)"
        case let .command(command): "command:\(command.rawValue)"
        case let .customCommand(command): "custom:\(command.id.uuidString)"
        }
    }
}

public struct QuickLaunchResult: Identifiable, Equatable, Sendable {
    public let item: QuickLaunchItem
    public let highlights: [Range<Int>]

    public var id: String { item.id }
}

@MainActor
@Observable
public final class QuickLaunchViewModel {
    public static let resultLimit = 50
    public static let backgroundThreshold = 200

    public var query = "" {
        didSet { if query != oldValue { updateResults() } }
    }
    public private(set) var results: [QuickLaunchResult] = []
    public private(set) var selectedIndex = 0
    public let candidates: [QuickLaunchItem]

    @ObservationIgnored private let suggestions: [QuickLaunchItem]
    @ObservationIgnored private let titles: [String]
    @ObservationIgnored private var rankTask: Task<Void, Never>?
    @ObservationIgnored private var generation = 0

    public init(candidates: [QuickLaunchItem], suggestions: [QuickLaunchItem]) {
        self.candidates = candidates
        self.suggestions = suggestions
        titles = candidates.map(\.title)
        updateResults()
    }

    public var selectedItem: QuickLaunchItem? {
        results.indices.contains(selectedIndex) ? results[selectedIndex].item : nil
    }

    public func moveSelection(by offset: Int) {
        guard !results.isEmpty else { return }
        selectedIndex = min(max(selectedIndex + offset, 0), results.count - 1)
    }

    public var selectedID: String? {
        results.indices.contains(selectedIndex) ? results[selectedIndex].id : nil
    }

    public func select(_ result: QuickLaunchResult) {
        if let index = results.firstIndex(of: result) { selectedIndex = index }
    }

    public func waitForResults() async {
        await rankTask?.value
    }

    private func updateResults() {
        generation += 1
        rankTask?.cancel()
        rankTask = nil
        let text = query
        guard !text.allSatisfy(\.isWhitespace) else {
            apply(suggestions.prefix(Self.resultLimit).map { QuickLaunchResult(item: $0, highlights: []) })
            return
        }
        guard candidates.count > Self.backgroundThreshold else {
            apply(FuzzyMatcher.rank(titles, query: text, limit: Self.resultLimit))
            return
        }
        let current = generation
        let titles = titles
        let limit = Self.resultLimit
        rankTask = Task { [weak self] in
            let ranked = await Task.detached(priority: .userInitiated) {
                FuzzyMatcher.rank(titles, query: text, limit: limit)
            }.value
            guard let self, !Task.isCancelled, generation == current else { return }
            apply(ranked)
        }
    }

    private func apply(_ ranked: [FuzzyRanked]) {
        apply(ranked.map { QuickLaunchResult(item: candidates[$0.index], highlights: $0.match.ranges) })
    }

    private func apply(_ results: [QuickLaunchResult]) {
        self.results = results
        selectedIndex = 0
    }
}
