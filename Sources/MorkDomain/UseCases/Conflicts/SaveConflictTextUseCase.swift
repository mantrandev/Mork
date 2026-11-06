import Foundation

public protocol SaveConflictTextUseCaseProtocol: Sendable {
    func execute(path: String, text: String, force: Bool) async throws
}

public final class SaveConflictTextUseCase: SaveConflictTextUseCaseProtocol {
    private let conflicts: ConflictRepositoryProtocol

    public init(conflicts: ConflictRepositoryProtocol) {
        self.conflicts = conflicts
    }

    public func execute(path: String, text: String, force: Bool) async throws {
        if !force {
            let remaining = ConflictParser.parse(text).blocks.count
            guard remaining == 0 else { throw ConflictError.markersRemain(remaining) }
        }
        try await conflicts.saveResolution(text, to: path)
    }
}
