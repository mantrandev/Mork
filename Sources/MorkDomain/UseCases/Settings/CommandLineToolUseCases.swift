import Foundation

public protocol LoadCommandLineToolStatusUseCaseProtocol: Sendable {
    func execute() async -> CommandLineToolStatus
}

public protocol InstallCommandLineToolUseCaseProtocol: Sendable {
    func execute() async throws -> CommandLineToolStatus
}

public final class LoadCommandLineToolStatusUseCase: LoadCommandLineToolStatusUseCaseProtocol {
    private let tool: CommandLineToolRepositoryProtocol

    public init(tool: CommandLineToolRepositoryProtocol) {
        self.tool = tool
    }

    public func execute() async -> CommandLineToolStatus {
        tool.status()
    }
}

public final class InstallCommandLineToolUseCase: InstallCommandLineToolUseCaseProtocol {
    private let tool: CommandLineToolRepositoryProtocol

    public init(tool: CommandLineToolRepositoryProtocol) {
        self.tool = tool
    }

    public func execute() async throws -> CommandLineToolStatus {
        try tool.install()
    }
}
