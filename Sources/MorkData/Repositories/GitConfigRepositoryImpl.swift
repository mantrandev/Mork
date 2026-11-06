import MorkDomain
import Foundation

public final class GitConfigRepositoryImpl: GitConfigRepositoryProtocol {
    private static let keyMissing: Int32 = 1
    private static let unsetKeyMissing: Int32 = 5

    private let executor: GitCommandExecuting
    private let environment: [String: String]

    public init(executor: GitCommandExecuting, environment: [String: String] = [:]) {
        self.executor = executor
        self.environment = environment
    }

    public func value(of key: GitConfigKey, scope: GitConfigScope) async throws -> String? {
        let output = try await executor.run(
            ["config", scope.flag, "--get", key.rawValue],
            input: nil,
            environment: environment,
            kind: .read,
            allowedExitCodes: [0, Self.keyMissing]
        )
        guard !output.isEmpty else { return nil }
        return output.hasSuffix("\n") ? String(output.dropLast()) : output
    }

    public func setValue(_ value: String, of key: GitConfigKey, scope: GitConfigScope) async throws {
        try await executor.write(["config", scope.flag, key.rawValue, value], environment: environment)
    }

    public func unsetValue(of key: GitConfigKey, scope: GitConfigScope) async throws {
        try await executor.write(["config", scope.flag, "--unset", key.rawValue], environment: environment, allowedExitCodes: [0, Self.unsetKeyMissing])
    }
}
