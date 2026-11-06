import Foundation

public protocol CustomCommandsRepositoryProtocol: Sendable {
    func load() -> [CustomCommand]
    func save(_ commands: [CustomCommand])
}

public protocol ShellCommandRepositoryProtocol: Sendable {
    func run(script: String) async throws
}
