import MorkDomain
import Foundation

public struct BisectDependencies: Sendable {
    public let startBisect: StartBisectUseCaseProtocol
    public let markBisectCommit: MarkBisectCommitUseCaseProtocol
    public let resetBisect: ResetBisectUseCaseProtocol
    public let loadBisectLog: LoadBisectLogUseCaseProtocol

    public init(
        startBisect: StartBisectUseCaseProtocol,
        markBisectCommit: MarkBisectCommitUseCaseProtocol,
        resetBisect: ResetBisectUseCaseProtocol,
        loadBisectLog: LoadBisectLogUseCaseProtocol
    ) {
        self.startBisect = startBisect
        self.markBisectCommit = markBisectCommit
        self.resetBisect = resetBisect
        self.loadBisectLog = loadBisectLog
    }
}
