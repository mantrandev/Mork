import Foundation

public protocol AddIgnoreRuleUseCaseProtocol: Sendable {
    func execute(rule: String, target: IgnoreTarget, path: String) async throws -> IgnoreRuleResult
}

public final class AddIgnoreRuleUseCase: AddIgnoreRuleUseCaseProtocol {
    private let ignore: IgnoreRepositoryProtocol

    public init(ignore: IgnoreRepositoryProtocol) {
        self.ignore = ignore
    }

    public func execute(rule: String, target: IgnoreTarget, path: String) async throws -> IgnoreRuleResult {
        guard let rule = GitIgnorePattern.custom(rule) else { throw GitDomainError.invalidIgnorePattern }
        let contents = try await ignore.contents(of: target) ?? ""
        let updated = GitIgnoreFile.appending(rule, to: contents)
        if let updated { try await ignore.write(updated, to: target) }
        let match = try await ignore.matchingRule(for: path)
        return IgnoreRuleResult(rule: rule, target: target, added: updated != nil, match: match)
    }
}
