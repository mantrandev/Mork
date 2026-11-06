import Foundation

public protocol LoadRepositoryFoldersUseCaseProtocol: Sendable {
    func execute() -> [URL]
}

public protocol AddRepositoryFolderUseCaseProtocol: Sendable {
    func execute(url: URL) -> [URL]
}

public protocol RemoveRepositoryFolderUseCaseProtocol: Sendable {
    func execute(url: URL) -> [URL]
}

public protocol ScanRepositoryFoldersUseCaseProtocol: Sendable {
    func execute(folders: [URL]) async -> [RepositoryScan]
}

public protocol LoadRepositoryStatusUseCaseProtocol: Sendable {
    func execute(repository: URL) async throws -> RepositoryStatusSummary
}

public protocol LoadRepositoryWorktreesUseCaseProtocol: Sendable {
    func execute(repository: URL) async throws -> [Worktree]
}

public protocol LoadRepositoryOverviewUseCaseProtocol: Sendable {
    func execute(repository: URL) async throws -> RepositoryOverview
}

public protocol LocateMainRepositoryUseCaseProtocol: Sendable {
    func execute(repository: URL) async -> URL?
}

public final class LoadRepositoryFoldersUseCase: LoadRepositoryFoldersUseCaseProtocol {
    private let store: RepositoryFoldersRepositoryProtocol

    public init(store: RepositoryFoldersRepositoryProtocol) {
        self.store = store
    }

    public func execute() -> [URL] {
        store.load()
    }
}

public final class AddRepositoryFolderUseCase: AddRepositoryFolderUseCaseProtocol {
    private let store: RepositoryFoldersRepositoryProtocol

    public init(store: RepositoryFoldersRepositoryProtocol) {
        self.store = store
    }

    public func execute(url: URL) -> [URL] {
        let folders = store.load()
        let path = RepositoryManagerCatalog.canonicalPath(url)
        guard !folders.contains(where: { RepositoryManagerCatalog.canonicalPath($0) == path }) else { return folders }
        let updated = folders + [RecentRepositoryList.canonical(url)]
        store.save(updated)
        return updated
    }
}

public final class RemoveRepositoryFolderUseCase: RemoveRepositoryFolderUseCaseProtocol {
    private let store: RepositoryFoldersRepositoryProtocol

    public init(store: RepositoryFoldersRepositoryProtocol) {
        self.store = store
    }

    public func execute(url: URL) -> [URL] {
        let folders = store.load()
        let path = RepositoryManagerCatalog.canonicalPath(url)
        let updated = folders.filter { RepositoryManagerCatalog.canonicalPath($0) != path }
        if updated != folders { store.save(updated) }
        return updated
    }
}

public final class ScanRepositoryFoldersUseCase: ScanRepositoryFoldersUseCaseProtocol {
    private let scanner: RepositoryScannerProtocol

    public init(scanner: RepositoryScannerProtocol) {
        self.scanner = scanner
    }

    public func execute(folders: [URL]) async -> [RepositoryScan] {
        let scanner = scanner
        return await withTaskGroup(of: (Int, RepositoryScan).self) { group in
            for (index, folder) in folders.enumerated() {
                group.addTask { (index, await scanner.scan(folder: folder, maxDepth: RepositoryScanRules.maxDepth)) }
            }
            var scans: [(Int, RepositoryScan)] = []
            for await scan in group { scans.append(scan) }
            return scans.sorted { $0.0 < $1.0 }.map(\.1)
        }
    }
}

public final class LoadRepositoryStatusUseCase: LoadRepositoryStatusUseCaseProtocol {
    private let inspector: RepositoryInspectorProtocol

    public init(inspector: RepositoryInspectorProtocol) {
        self.inspector = inspector
    }

    public func execute(repository: URL) async throws -> RepositoryStatusSummary {
        try await inspector.status(of: repository)
    }
}

public final class LoadRepositoryWorktreesUseCase: LoadRepositoryWorktreesUseCaseProtocol {
    private let inspector: RepositoryInspectorProtocol

    public init(inspector: RepositoryInspectorProtocol) {
        self.inspector = inspector
    }

    public func execute(repository: URL) async throws -> [Worktree] {
        try await inspector.worktrees(of: repository)
    }
}

public final class LoadRepositoryOverviewUseCase: LoadRepositoryOverviewUseCaseProtocol {
    private let inspector: RepositoryInspectorProtocol

    public init(inspector: RepositoryInspectorProtocol) {
        self.inspector = inspector
    }

    public func execute(repository: URL) async throws -> RepositoryOverview {
        try await inspector.overview(of: repository)
    }
}

public final class LocateMainRepositoryUseCase: LocateMainRepositoryUseCaseProtocol {
    private let inspector: RepositoryInspectorProtocol

    public init(inspector: RepositoryInspectorProtocol) {
        self.inspector = inspector
    }

    public func execute(repository: URL) async -> URL? {
        guard let common = try? await inspector.commonDirectory(of: repository),
              let main = RepositoryScanRules.mainRepository(forCommonDirectory: common) else { return nil }
        let mainPath = main.resolvingSymlinksInPath().path
        return mainPath == repository.standardizedFileURL.resolvingSymlinksInPath().path ? nil : main
    }
}
