import MorkDomain
import Foundation

public struct RevisionDependencies: Sendable {
    public let checkoutCommit: CheckoutCommitUseCaseProtocol
    public let createBranchAtCommit: CreateBranchAtCommitUseCaseProtocol
    public let createTagAtCommit: CreateTagAtCommitUseCaseProtocol
    public let cherryPickCommit: CherryPickCommitUseCaseProtocol
    public let revertCommit: RevertCommitUseCaseProtocol
    public let resetCurrentBranch: ResetCurrentBranchUseCaseProtocol
    public let continueOperation: ContinueOperationUseCaseProtocol
    public let abortOperation: AbortOperationUseCaseProtocol

    public init(
        checkoutCommit: CheckoutCommitUseCaseProtocol,
        createBranchAtCommit: CreateBranchAtCommitUseCaseProtocol,
        createTagAtCommit: CreateTagAtCommitUseCaseProtocol,
        cherryPickCommit: CherryPickCommitUseCaseProtocol,
        revertCommit: RevertCommitUseCaseProtocol,
        resetCurrentBranch: ResetCurrentBranchUseCaseProtocol,
        continueOperation: ContinueOperationUseCaseProtocol,
        abortOperation: AbortOperationUseCaseProtocol
    ) {
        self.checkoutCommit = checkoutCommit
        self.createBranchAtCommit = createBranchAtCommit
        self.createTagAtCommit = createTagAtCommit
        self.cherryPickCommit = cherryPickCommit
        self.revertCommit = revertCommit
        self.resetCurrentBranch = resetCurrentBranch
        self.continueOperation = continueOperation
        self.abortOperation = abortOperation
    }
}
