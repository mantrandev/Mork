import MorkDomain
import Foundation
import Observation

@MainActor
@Observable
public final class ExternalToolRuns {
    public struct Run: Equatable, Sendable {
        public let tool: String
        public let role: ExternalToolRole

        public init(tool: String, role: ExternalToolRole) {
            self.tool = tool
            self.role = role
        }
    }

    public private(set) var running: [String: Run] = [:]
    public private(set) var messages: [String: String] = [:]
    @ObservationIgnored private var tasks: [String: Task<Void, Never>] = [:]

    public init() {}

    public func run(for path: String) -> Run? {
        running[path]
    }

    public func message(for path: String) -> String? {
        messages[path]
    }

    public func dismissMessage(for path: String) {
        messages[path] = nil
    }

    public func cancel(_ path: String) {
        tasks[path]?.cancel()
    }

    public func waitUntilIdle() async {
        while let task = tasks.values.first {
            await task.value
        }
    }

    @discardableResult
    func start(_ path: String, _ run: Run, body: @escaping @MainActor () async -> String?) -> Bool {
        guard running[path] == nil else { return false }
        running[path] = run
        messages[path] = nil
        tasks[path] = Task { [weak self] in
            let message = await body()
            guard let self else { return }
            self.running[path] = nil
            self.messages[path] = message
            self.tasks[path] = nil
        }
        return true
    }
}
