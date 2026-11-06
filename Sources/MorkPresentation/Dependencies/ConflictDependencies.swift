import MorkDomain
import Foundation

public struct ConflictDependencies: Sendable {
    public let loadConflict: LoadConflictUseCaseProtocol
    public let resolveConflictFile: ResolveConflictFileUseCaseProtocol
    public let saveConflictText: SaveConflictTextUseCaseProtocol
    public let markConflictResolved: MarkConflictResolvedUseCaseProtocol
    public let concludeMerge: ConcludeMergeUseCaseProtocol

    public init(
        loadConflict: LoadConflictUseCaseProtocol,
        resolveConflictFile: ResolveConflictFileUseCaseProtocol,
        saveConflictText: SaveConflictTextUseCaseProtocol,
        markConflictResolved: MarkConflictResolvedUseCaseProtocol,
        concludeMerge: ConcludeMergeUseCaseProtocol
    ) {
        self.loadConflict = loadConflict
        self.resolveConflictFile = resolveConflictFile
        self.saveConflictText = saveConflictText
        self.markConflictResolved = markConflictResolved
        self.concludeMerge = concludeMerge
    }
}
