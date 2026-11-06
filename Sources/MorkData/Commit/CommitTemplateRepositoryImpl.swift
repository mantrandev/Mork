import MorkDomain
import Foundation

public final class CommitTemplateRepositoryImpl: CommitTemplateRepositoryProtocol {
    private static let keyMissing: Int32 = 1
    private static let automaticCommentCharacter = "auto"

    private let executor: GitCommandExecuting
    private let root: URL
    private let environment: [String: String]

    public init(executor: GitCommandExecuting, root: URL, environment: [String: String] = [:]) {
        self.executor = executor
        self.root = root
        self.environment = environment
    }

    public func template() async throws -> CommitTemplate? {
        let path = try await value(["config", "--type=path", "--get", "commit.template"])
        guard !path.isEmpty else { return nil }
        let file = path.hasPrefix("/") ? URL(fileURLWithPath: path) : root.appendingPathComponent(path)
        guard let data = FileManager.default.contents(atPath: file.path) else { return nil }
        let comment = try await value(["config", "--get", "core.commentChar"]).trimmingCharacters(in: .whitespaces)
        return CommitTemplate(
            text: String(decoding: data, as: UTF8.self),
            commentPrefix: comment == Self.automaticCommentCharacter ? CommitTemplate.defaultCommentPrefix : comment
        )
    }

    private func value(_ arguments: [String]) async throws -> String {
        try await executor.run(arguments, input: nil, environment: environment, kind: .read, allowedExitCodes: [0, Self.keyMissing])
            .trimmingCharacters(in: .newlines)
    }
}
