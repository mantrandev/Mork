import Foundation

public protocol DeleteTagUseCaseProtocol: Sendable {
    func execute(tag: Tag) async throws
}

public final class DeleteTagUseCase: DeleteTagUseCaseProtocol {
    private let tags: TagRepositoryProtocol

    public init(tags: TagRepositoryProtocol) {
        self.tags = tags
    }

    public func execute(tag: Tag) async throws {
        try await tags.delete(tag)
    }
}
