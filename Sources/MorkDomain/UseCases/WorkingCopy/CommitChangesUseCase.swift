import Foundation

public protocol CommitChangesUseCaseProtocol: Sendable {
    func execute(message: String, amend: Bool) async throws
}

public final class CommitChangesUseCase: CommitChangesUseCaseProtocol {
    private let workingCopy: WorkingCopyRepositoryProtocol
    private let templates: CommitTemplateRepositoryProtocol?

    public init(workingCopy: WorkingCopyRepositoryProtocol, templates: CommitTemplateRepositoryProtocol? = nil) {
        self.workingCopy = workingCopy
        self.templates = templates
    }

    public func execute(message: String, amend: Bool) async throws {
        var message = message
        if let template = try await templates?.template() {
            message = template.cleaned(message)
        }
        message = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty else { throw GitDomainError.emptyCommitMessage }
        if !amend {
            let hasStaged = try await workingCopy.changes().contains(where: \.isStaged)
            guard hasStaged else { throw GitDomainError.nothingStaged }
        }
        try await workingCopy.commit(message: message, amend: amend)
    }
}
