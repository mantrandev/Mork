import Foundation
import Observation

@MainActor
@Observable
public final class CommitMessageStore {
    public static let debounce: Duration = .milliseconds(30)

    public private(set) var messages: [String: String] = [:]
    @ObservationIgnored private var requested: Set<String> = []
    @ObservationIgnored private var pending: [String] = []
    @ObservationIgnored var task: Task<Void, Never>?

    public init() {}

    public func message(of hash: String) -> String? {
        messages[hash]
    }

    func request(_ hash: String) -> Bool {
        guard messages[hash] == nil, requested.insert(hash).inserted else { return false }
        pending.append(hash)
        return true
    }

    func takePending(limit: Int) -> [String] {
        let batch = Array(pending.prefix(limit))
        pending.removeFirst(batch.count)
        return batch
    }

    func store(_ results: [String: String]) {
        guard !results.isEmpty else { return }
        messages.merge(results) { _, new in new }
    }

    func remember(_ message: String, for hash: String) {
        guard messages[hash] != message else { return }
        messages[hash] = message
    }

    deinit {
        task?.cancel()
    }
}
