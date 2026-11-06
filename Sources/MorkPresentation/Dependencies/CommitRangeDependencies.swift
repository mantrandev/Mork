import MorkDomain
import Foundation

public struct CommitRangeDependencies: Sendable {
    public let cherryPickCommits: CherryPickCommitsUseCaseProtocol
    public let revertCommits: RevertCommitsUseCaseProtocol
    public let checkRange: CheckCommitRangeUseCaseProtocol
    public let loadChanges: LoadCommitRangeChangesUseCaseProtocol
    public let loadDiff: LoadCommitRangeDiffUseCaseProtocol
    public let savePatch: SaveCommitRangePatchUseCaseProtocol
    public let folderPanel: FolderPanelProtocol

    public init(
        cherryPickCommits: CherryPickCommitsUseCaseProtocol,
        revertCommits: RevertCommitsUseCaseProtocol,
        checkRange: CheckCommitRangeUseCaseProtocol,
        loadChanges: LoadCommitRangeChangesUseCaseProtocol,
        loadDiff: LoadCommitRangeDiffUseCaseProtocol,
        savePatch: SaveCommitRangePatchUseCaseProtocol,
        folderPanel: FolderPanelProtocol
    ) {
        self.cherryPickCommits = cherryPickCommits
        self.revertCommits = revertCommits
        self.checkRange = checkRange
        self.loadChanges = loadChanges
        self.loadDiff = loadDiff
        self.savePatch = savePatch
        self.folderPanel = folderPanel
    }
}
