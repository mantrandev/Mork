import MorkDomain

public struct TagActionsDependencies: Sendable {
    public let loadDetails: LoadTagDetailsUseCaseProtocol
    public let merge: MergeTagUseCaseProtocol
    public let rebase: RebaseTagUseCaseProtocol
    public let deleteFromRemotes: DeleteTagFromRemotesUseCaseProtocol

    public init(loadDetails: LoadTagDetailsUseCaseProtocol, merge: MergeTagUseCaseProtocol, rebase: RebaseTagUseCaseProtocol, deleteFromRemotes: DeleteTagFromRemotesUseCaseProtocol) {
        self.loadDetails = loadDetails
        self.merge = merge
        self.rebase = rebase
        self.deleteFromRemotes = deleteFromRemotes
    }
}
