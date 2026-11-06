import Foundation

public protocol LocateRepositoryUseCaseProtocol: Sendable {
    func execute(url: URL) async throws -> URL
}

public final class LocateRepositoryUseCase: LocateRepositoryUseCaseProtocol {
    private let locator: RepositoryLocatorProtocol

    public init(locator: RepositoryLocatorProtocol) {
        self.locator = locator
    }

    public func execute(url: URL) async throws -> URL {
        do {
            return try await locator.locateRepository(containing: url)
        } catch {
            throw GitDomainError.notARepository(path: url.path)
        }
    }
}
