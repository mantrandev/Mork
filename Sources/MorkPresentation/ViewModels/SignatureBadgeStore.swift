import MorkDomain
import Foundation
import Observation

@MainActor
@Observable
public final class SignatureBadgeStore {
    public static let debounce: Duration = .milliseconds(50)

    public private(set) var statuses: [String: CommitSignature] = [:]
    @ObservationIgnored private var requested: Set<String> = []
    @ObservationIgnored private var pending: [String] = []
    @ObservationIgnored var task: Task<Void, Never>?

    public init() {}

    public func status(of hash: String) -> CommitSignature? {
        statuses[hash]
    }

    func request(_ hash: String) -> Bool {
        guard requested.insert(hash).inserted else { return false }
        pending.append(hash)
        return true
    }

    func takePending(limit: Int) -> [String] {
        let batch = Array(pending.prefix(limit))
        pending.removeFirst(batch.count)
        return batch
    }

    func store(_ results: [String: CommitSignature], for batch: [String]) {
        var updated = statuses
        for hash in batch { updated[hash] = results[hash] ?? CommitSignature.none }
        statuses = updated
    }

    deinit {
        task?.cancel()
    }
}
