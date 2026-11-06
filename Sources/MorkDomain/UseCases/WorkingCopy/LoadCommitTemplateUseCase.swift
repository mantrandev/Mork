import Foundation

public protocol LoadCommitTemplateUseCaseProtocol: Sendable {
    func execute() async throws -> CommitTemplate?
}

public final class LoadCommitTemplateUseCase: LoadCommitTemplateUseCaseProtocol {
    private let templates: CommitTemplateRepositoryProtocol

    public init(templates: CommitTemplateRepositoryProtocol) {
        self.templates = templates
    }

    public func execute() async throws -> CommitTemplate? {
        try await templates.template()
    }
}
