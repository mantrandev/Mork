import Foundation

public protocol CreateTagUseCaseProtocol: Sendable {
    func execute(name: String, message: String) async throws
}

public final class CreateTagUseCase: CreateTagUseCaseProtocol {
    private let tags: TagRepositoryProtocol

    public init(tags: TagRepositoryProtocol) {
        self.tags = tags
    }

    public func execute(name: String, message: String) async throws {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw GitDomainError.emptyTagName }
        try await tags.create(named: name, message: message.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}
