import Foundation

public protocol RunGitCommandUseCaseProtocol: Sendable {
    func execute(commandLine: String) async throws
}

public final class RunGitCommandUseCase: RunGitCommandUseCaseProtocol {
    private let commands: GitCommandRepositoryProtocol

    public init(commands: GitCommandRepositoryProtocol) {
        self.commands = commands
    }

    public func execute(commandLine: String) async throws {
        var words = ShellWords.split(commandLine)
        if words.first == "git" { words.removeFirst() }
        guard !words.isEmpty else { return }
        try await commands.run(arguments: words)
    }
}
