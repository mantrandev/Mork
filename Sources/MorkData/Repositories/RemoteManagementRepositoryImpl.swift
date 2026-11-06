import MorkDomain
import Foundation

public final class RemoteManagementRepositoryImpl: RemoteManagementRepositoryProtocol {
    private static let configKeyMissing: Int32 = 5

    private let executor: GitCommandExecuting

    public init(executor: GitCommandExecuting) {
        self.executor = executor
    }

    public func remoteList() async throws -> [Remote] {
        GitOutputParser.remotes(try await executor.read(["remote", "-v"]))
    }

    public func addRemote(named name: String, url: String) async throws {
        try await executor.write(["remote", "add", name, url])
    }

    public func renameRemote(named name: String, to newName: String) async throws {
        try await executor.write(["remote", "rename", name, newName])
    }

    public func setFetchURL(_ url: String, ofRemoteNamed name: String) async throws {
        try await executor.write(["remote", "set-url", name, url])
    }

    public func setPushURL(_ url: String?, ofRemoteNamed name: String) async throws {
        if let url {
            try await executor.write(["remote", "set-url", "--push", name, url])
        } else {
            try await executor.write(["config", "--unset-all", "remote.\(name).pushurl"], allowedExitCodes: [0, Self.configKeyMissing])
        }
    }

    public func removeRemote(named name: String) async throws {
        try await executor.write(["remote", "remove", name])
    }

    public func fetchRemote(named name: String) async throws {
        try await executor.write(["fetch", "--prune", name])
    }

    public func pruneRemote(named name: String) async throws {
        try await executor.write(["remote", "prune", name])
    }

    public func deleteRemoteBranch(named branch: String, onRemote remote: String) async throws {
        try await executor.write(["push", remote, "--delete", branch])
    }

    public func setUpstream(of branch: String, to upstream: String) async throws {
        try await executor.write(["branch", "--set-upstream-to=\(upstream)", branch])
    }

    public func unsetUpstream(of branch: String) async throws {
        try await executor.write(["branch", "--unset-upstream", branch])
    }
}
