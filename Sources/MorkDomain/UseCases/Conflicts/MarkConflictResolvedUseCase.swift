import Foundation

public protocol MarkConflictResolvedUseCaseProtocol: Sendable {
    func execute(path: String, force: Bool) async throws
}

public final class MarkConflictResolvedUseCase: MarkConflictResolvedUseCaseProtocol {
    private let conflicts: ConflictRepositoryProtocol

    public init(conflicts: ConflictRepositoryProtocol) {
        self.conflicts = conflicts
    }

    public func execute(path: String, force: Bool) async throws {
        if !force, let data = try await conflicts.contents(of: path), case let .text(document) = ConflictParser.content(of: data), !document.blocks.isEmpty {
            throw ConflictError.markersRemain(document.blocks.count)
        }
        try await conflicts.markResolved(path: path)
    }
}
