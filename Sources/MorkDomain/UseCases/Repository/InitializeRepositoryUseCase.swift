import Foundation

public protocol InitializeRepositoryUseCaseProtocol: Sendable {
    func execute(url: URL) async throws -> URL
}

public final class InitializeRepositoryUseCase: InitializeRepositoryUseCaseProtocol {
    private let locator: RepositoryLocatorProtocol

    public init(locator: RepositoryLocatorProtocol) {
        self.locator = locator
    }

    public func execute(url: URL) async throws -> URL {
        try await locator.initializeRepository(at: url)
        return try await locator.locateRepository(containing: url)
    }
}
