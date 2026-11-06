import MorkDomain
import Foundation
import Observation

@MainActor
@Observable
public final class RepositoryManagerViewModel {
    public private(set) var folders: [URL]
    public private(set) var scans: [RepositoryScan] = [] {
        didSet { if scans != oldValue { rebuildCatalog() } }
    }
    public internal(set) var recents: [URL] = [] {
        didSet { if recents != oldValue { rebuildCatalog() } }
    }
    public private(set) var groups: [RepositoryGroup] = []
    public private(set) var openableRepositories: [DiscoveredRepository] = []
    public private(set) var isScanning = false
    public var warning: String?
    public var selection: RepositoryManagerSelection?
    public private(set) var overviewTarget: URL?
    public private(set) var overview: LoadedRepositoryOverview?
    public private(set) var overviewError: String?
    public var lessonBrowser: LessonBrowserViewModel?
    public let welcomeLessons = LessonCatalog.standard.coreTopics

    @ObservationIgnored private var overviews: [String: RepositoryOverview] = [:]
    @ObservationIgnored private var overviewGeneration = 0
    private var statuses: [String: RepositoryStatusSummary] = [:]
    private var worktreeLists: [String: Loadable<[Worktree]>] = [:]
    private var expanded: Set<String> = []
    @ObservationIgnored private var requestedStatuses: Set<String> = []
    @ObservationIgnored private var reportedUnreadable: Set<String> = []
    @ObservationIgnored private var scanGeneration = 0
    @ObservationIgnored private let dependencies: RepositoryManagerDependencies

    public init(dependencies: RepositoryManagerDependencies) {
        self.dependencies = dependencies
        folders = dependencies.loadFolders.execute()
    }

    private func rebuildCatalog() {
        groups = RepositoryManagerCatalog.groups(scans: scans, recents: recents)
        openableRepositories = RepositoryManagerCatalog.openableRepositories(in: scans)
    }

    public func rescan() async {
        scanGeneration += 1
        let generation = scanGeneration
        isScanning = true
        let results = await dependencies.scanFolders.execute(folders: folders)
        guard generation == scanGeneration else { return }
        isScanning = false
        scans = results
        requestedStatuses = Set(statuses.keys)
        worktreeLists = [:]
        report(results.flatMap(\.unreadable))
    }

    public func chooseFolder(prompt: String) async -> URL? {
        await dependencies.folderPanel.chooseFolder(prompt: prompt)
    }

    public func addFolder() async {
        guard let folder = await chooseFolder(prompt: "Add Folder") else { return }
        await addFolder(folder)
    }

    public func addFolder(_ folder: URL) async {
        folders = dependencies.addFolder.execute(url: folder)
        await rescan()
    }

    public func removeFolder(_ folder: URL) {
        folders = dependencies.removeFolder.execute(url: folder)
        let remaining = Set(folders.map(\.standardizedFileURL.path))
        scans.removeAll { !remaining.contains($0.folder.standardizedFileURL.path) }
    }

    public func status(of repository: URL) -> RepositoryStatusSummary? {
        statuses[Self.key(repository)]
    }

    public func loadStatus(for repository: URL) async {
        let key = Self.key(repository)
        guard !isBare(repository), requestedStatuses.insert(key).inserted else { return }
        guard let status = try? await dependencies.loadStatus.execute(repository: repository) else { return }
        statuses[key] = status
    }

    public var isOverviewStale: Bool {
        overview.map { Self.key($0.url) != overviewTarget.map(Self.key) } ?? false
    }

    public func openLesson(_ command: String) {
        lessonBrowser = LessonBrowserViewModel(selecting: command)
    }

    public func loadOverview(for repository: URL?) async {
        overviewGeneration += 1
        let generation = overviewGeneration
        overviewTarget = repository
        overviewError = nil
        guard let repository, !isBare(repository) else { return }
        let key = Self.key(repository)
        if let cached = overviews[key] { overview = LoadedRepositoryOverview(url: repository, value: cached) }
        do {
            let value = try await dependencies.loadOverview.execute(repository: repository)
            guard generation == overviewGeneration else { return }
            overviews[key] = value
            overview = LoadedRepositoryOverview(url: repository, value: value)
        } catch {
            guard generation == overviewGeneration else { return }
            overview = nil
            overviewError = error.localizedDescription
        }
    }

    public func isExpanded(_ repository: URL) -> Bool {
        expanded.contains(Self.key(repository))
    }

    public func worktrees(of repository: URL) -> Loadable<[Worktree]> {
        worktreeLists[Self.key(repository)] ?? .idle
    }

    public func toggleWorktrees(for repository: URL) async {
        let key = Self.key(repository)
        if expanded.remove(key) != nil { return }
        expanded.insert(key)
        if case .loaded = worktrees(of: repository) { return }
        worktreeLists[key] = .loading
        do {
            worktreeLists[key] = .loaded(try await dependencies.loadWorktrees.execute(repository: repository))
        } catch {
            worktreeLists[key] = .failed(error.localizedDescription)
        }
    }

    private func isBare(_ repository: URL) -> Bool {
        let key = Self.key(repository)
        return scans.contains { $0.repositories.contains { $0.isBare && Self.key($0.url) == key } }
    }

    private func report(_ unreadable: [URL]) {
        let fresh = unreadable.filter { reportedUnreadable.insert($0.path).inserted }
        guard !fresh.isEmpty else { return }
        warning = "Could not read \(fresh.count == 1 ? "this folder" : "these folders"), so they were skipped: " + fresh.map(\.path).joined(separator: ", ")
    }

    private static func key(_ url: URL) -> String {
        url.standardizedFileURL.path
    }
}

public struct RepositoryManagerSelection: Hashable, Sendable {
    public let group: String
    public let url: URL

    public init(group: String, url: URL) {
        self.group = group
        self.url = url
    }
}

public struct LoadedRepositoryOverview: Equatable, Sendable {
    public let url: URL
    public let value: RepositoryOverview
}
