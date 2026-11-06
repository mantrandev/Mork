import MorkDomain
import Foundation

public struct ExplorationDependencies: Sendable {
    public let searchCommits: SearchCommitsUseCaseProtocol
    public let loadCommit: LoadCommitUseCaseProtocol
    public let loadReflog: LoadReflogUseCaseProtocol
    public let loadFileHistory: LoadFileHistoryUseCaseProtocol
    public let blameFile: BlameFileUseCaseProtocol
    public let loadLineHistory: LoadLineHistoryUseCaseProtocol
    public let loadImageDiff: LoadImageDiffUseCaseProtocol
    public let loadHistoryOptions: LoadHistoryOptionsUseCaseProtocol
    public let saveHistoryOptions: SaveHistoryOptionsUseCaseProtocol
    public let tree: CommitTreeDependencies
    public let compare: LocalChangesComparisonDependencies

    public init(
        searchCommits: SearchCommitsUseCaseProtocol,
        loadCommit: LoadCommitUseCaseProtocol,
        loadReflog: LoadReflogUseCaseProtocol,
        loadFileHistory: LoadFileHistoryUseCaseProtocol,
        blameFile: BlameFileUseCaseProtocol,
        loadLineHistory: LoadLineHistoryUseCaseProtocol,
        loadImageDiff: LoadImageDiffUseCaseProtocol,
        loadHistoryOptions: LoadHistoryOptionsUseCaseProtocol,
        saveHistoryOptions: SaveHistoryOptionsUseCaseProtocol,
        tree: CommitTreeDependencies,
        compare: LocalChangesComparisonDependencies
    ) {
        self.searchCommits = searchCommits
        self.loadCommit = loadCommit
        self.loadReflog = loadReflog
        self.loadFileHistory = loadFileHistory
        self.blameFile = blameFile
        self.loadLineHistory = loadLineHistory
        self.loadImageDiff = loadImageDiff
        self.loadHistoryOptions = loadHistoryOptions
        self.saveHistoryOptions = saveHistoryOptions
        self.tree = tree
        self.compare = compare
    }
}
