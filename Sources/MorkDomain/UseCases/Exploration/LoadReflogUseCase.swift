import Foundation

public protocol LoadReflogUseCaseProtocol: Sendable {
    func execute(limit: Int) async throws -> [ReflogEntry]
}

public final class LoadReflogUseCase: LoadReflogUseCaseProtocol {
    private let reflog: ReflogRepositoryProtocol

    public init(reflog: ReflogRepositoryProtocol) {
        self.reflog = reflog
    }

    public func execute(limit: Int) async throws -> [ReflogEntry] {
        try await reflog.reflog(limit: limit)
    }
}
