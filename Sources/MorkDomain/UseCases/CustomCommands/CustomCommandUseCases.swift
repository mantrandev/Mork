import Foundation

public protocol LoadCustomCommandsUseCaseProtocol: Sendable {
    func execute() -> [CustomCommand]
}

public protocol SaveCustomCommandsUseCaseProtocol: Sendable {
    func execute(_ commands: [CustomCommand])
}

public protocol RunCustomCommandUseCaseProtocol: Sendable {
    func execute(_ command: CustomCommand, context: CustomCommandContext) async throws
}

public final class LoadCustomCommandsUseCase: LoadCustomCommandsUseCaseProtocol {
    private let store: CustomCommandsRepositoryProtocol

    public init(store: CustomCommandsRepositoryProtocol) {
        self.store = store
    }

    public func execute() -> [CustomCommand] {
        store.load()
    }
}

public final class SaveCustomCommandsUseCase: SaveCustomCommandsUseCaseProtocol {
    private let store: CustomCommandsRepositoryProtocol

    public init(store: CustomCommandsRepositoryProtocol) {
        self.store = store
    }

    public func execute(_ commands: [CustomCommand]) {
        store.save(commands)
    }
}

public final class RunCustomCommandUseCase: RunCustomCommandUseCaseProtocol {
    private let git: GitCommandRepositoryProtocol
    private let shell: ShellCommandRepositoryProtocol

    public init(git: GitCommandRepositoryProtocol, shell: ShellCommandRepositoryProtocol) {
        self.git = git
        self.shell = shell
    }

    public func execute(_ command: CustomCommand, context: CustomCommandContext) async throws {
        if let problem = command.problem { throw problem }
        switch try CustomCommandExpander.expand(command, in: context) {
        case let .git(arguments): try await git.run(arguments: arguments)
        case let .shell(script): try await shell.run(script: script)
        }
    }
}
