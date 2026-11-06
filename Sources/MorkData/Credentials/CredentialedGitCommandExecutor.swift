import MorkDomain
import Foundation

public protocol GitEnvironmentExecuting: GitStreamingCommandExecuting {
    func run(
        _ arguments: [String],
        input: String?,
        environment: [String: String],
        notes: [String],
        kind: GitCommandKind,
        allowedExitCodes: Set<Int32>?
    ) async throws -> String

    func run(
        _ arguments: [String],
        environment: [String: String],
        notes: [String],
        kind: GitCommandKind,
        allowedExitCodes: Set<Int32>?,
        onProgress: @escaping @Sendable (String) -> Void
    ) async throws -> String
}

extension ProcessGitCommandExecutor: GitEnvironmentExecuting {}

enum NetworkCommand: Equatable, Sendable {
    case none
    case repositoryRemotes
    case urls([String])

    private static let optionsWithValue: Set<String> = ["-c", "-C", "--git-dir", "--work-tree", "--namespace"]
    private static let remoteCommands: Set<String> = ["fetch", "pull", "push", "ls-remote"]
    private static let remoteActions: Set<String> = ["update", "prune", "show"]

    static func classify(_ arguments: [String]) -> NetworkCommand {
        var index = arguments.startIndex
        while index < arguments.endIndex, arguments[index].hasPrefix("-") {
            index += optionsWithValue.contains(arguments[index]) ? 2 : 1
        }
        guard index < arguments.endIndex else { return .none }
        let command = arguments[index]
        let rest = Array(arguments[(index + 1)...])
        let urls = rest.filter { $0.contains("://") }
        let action = rest.first { !$0.hasPrefix("-") }
        switch command {
        case "clone":
            return urls.isEmpty ? .none : .urls(urls)
        case _ where remoteCommands.contains(command):
            return urls.isEmpty ? .repositoryRemotes : .urls(urls)
        case "remote":
            return action.map(remoteActions.contains) == true ? .repositoryRemotes : .none
        case "submodule":
            switch action {
            case "update": return .repositoryRemotes
            case "add": return urls.isEmpty ? .none : .urls(urls)
            default: return .none
            }
        default:
            return .none
        }
    }
}

public final class CredentialedGitCommandExecutor: GitStreamingCommandExecuting {
    private static let remotePattern = "^(remote\\..*\\.(url|pushurl)|submodule\\..*\\.url)$"

    let base: GitEnvironmentExecuting
    private let credentials: GitCredentialProviding
    private let askpass: AskpassScripts

    public init(base: GitEnvironmentExecuting, credentials: GitCredentialProviding, askpass: AskpassScripts) {
        self.base = base
        self.credentials = credentials
        self.askpass = askpass
    }

    public func run(_ arguments: [String], input: String?, environment: [String: String], kind: GitCommandKind, allowedExitCodes: Set<Int32>?) async throws -> String {
        let command = NetworkCommand.classify(arguments)
        guard command != .none else {
            return try await base.run(arguments, input: input, environment: environment, kind: kind, allowedExitCodes: allowedExitCodes)
        }
        let prepared = try await prepare(command)
        return try await translatingAuthenticationFailures(prepared) {
            try await base.run(arguments, input: input, environment: environment.merging(prepared.environment) { _, new in new }, notes: prepared.plan.notes, kind: kind, allowedExitCodes: allowedExitCodes)
        }
    }

    public func readLines(_ arguments: [String], matching lines: Set<String>) async throws -> [String] {
        try await base.readLines(arguments, matching: lines)
    }

    public func runData(_ arguments: [String], kind: GitCommandKind, allowedExitCodes: Set<Int32>?) async throws -> Data {
        try await base.runData(arguments, kind: kind, allowedExitCodes: allowedExitCodes)
    }

    public func run(_ arguments: [String], kind: GitCommandKind, allowedExitCodes: Set<Int32>?, onProgress: @escaping @Sendable (String) -> Void) async throws -> String {
        let command = NetworkCommand.classify(arguments)
        guard command != .none else {
            return try await base.run(arguments, kind: kind, allowedExitCodes: allowedExitCodes, onProgress: onProgress)
        }
        let prepared = try await prepare(command)
        return try await translatingAuthenticationFailures(prepared) {
            try await base.run(arguments, environment: prepared.environment, notes: prepared.plan.notes, kind: kind, allowedExitCodes: allowedExitCodes, onProgress: onProgress)
        }
    }

    private struct Prepared {
        let remotes: [String]
        let plan: GitCredentialPlan
        let environment: [String: String]
    }

    private func prepare(_ command: NetworkCommand) async throws -> Prepared {
        guard credentials.hasAccounts() else { return Prepared(remotes: Self.explicitURLs(command), plan: .empty, environment: [:]) }
        let remotes: [String]
        switch command {
        case .none: remotes = []
        case let .urls(urls): remotes = urls
        case .repositoryRemotes: remotes = await repositoryRemoteURLs()
        }
        let plan = await credentials.plan(for: remotes)
        return Prepared(remotes: remotes, plan: plan, environment: try CredentialEnvironment.make(for: plan, askpass: askpass))
    }

    private static func explicitURLs(_ command: NetworkCommand) -> [String] {
        if case let .urls(urls) = command { return urls }
        return []
    }

    private func repositoryRemoteURLs() async -> [String] {
        async let configured = base.run(["config", "--get-regexp", Self.remotePattern], input: nil, environment: [:], kind: .read, allowedExitCodes: [0, 1])
        async let modules = base.run(["config", "-f", ".gitmodules", "--get-regexp", "^submodule\\..*\\.url$"], input: nil, environment: [:], kind: .read, allowedExitCodes: nil)
        let output = ((try? await configured) ?? "") + "\n" + ((try? await modules) ?? "")
        var seen: Set<String> = []
        return output.split(whereSeparator: \.isNewline).compactMap { line in
            line.split(separator: " ", maxSplits: 1).dropFirst().first.map(String.init)
        }.filter { seen.insert($0).inserted }
    }

    private func translatingAuthenticationFailures(_ prepared: Prepared, _ body: () async throws -> String) async throws -> String {
        do {
            return try await body()
        } catch let GitDomainError.commandFailed(command, exitCode, message) where GitAuthenticationFailure.matches(message) {
            guard let host = prepared.plan.credentials.first?.host ?? Self.httpsHost(in: message) ?? prepared.remotes.lazy.compactMap({ RemoteEndpoint.https($0)?.host }).first else {
                throw GitDomainError.commandFailed(command: command, exitCode: exitCode, message: message)
            }
            throw AccountError.gitAuthenticationFailed(host: host, login: prepared.plan.accounts[host]?.login)
        }
    }

    private static func httpsHost(in message: String) -> String? {
        guard let range = message.range(of: #"https://[^\s'"/]+"#, options: .regularExpression) else { return nil }
        return RemoteEndpoint.https(String(message[range]))?.host
    }
}
