import MorkDomain
import Foundation

@MainActor
final class CommitPreloader {
    struct PreparedFile: Sendable {
        let text: String
        let document: DiffDocument
        let submoduleSummary: String?
        let lfsPointer: LFSPointerChange?
    }

    struct PreparedDetail: Sendable {
        let text: String
        let document: DiffDocument
        let submoduleSummary: String?
        let lfsPointer: LFSPointerChange?
        let tabWidth: Int
        var files: [String: PreparedFile] = [:]
    }

    let capacity: Int
    private var summaries: [String: CommitSummary] = [:]
    private var details: [String: PreparedDetail] = [:]
    private var summaryTasks: [String: Task<Result<CommitSummary, Error>, Never>] = [:]
    private var detailTasks: [String: Task<Result<PreparedDetail, Error>, Never>] = [:]
    private var order: [String] = []
    var hoverTask: Task<Void, Never>?
    var hoveredHash: String?

    init(capacity: Int) {
        self.capacity = capacity
    }

    func summary(of hash: String) -> CommitSummary? {
        summaries[hash]
    }

    func detail(of hash: String, tabWidth: Int) -> PreparedDetail? {
        details[hash].flatMap { $0.tabWidth == tabWidth ? $0 : nil }
    }

    func pendingDetail(of hash: String) -> Task<Result<PreparedDetail, Error>, Never>? {
        detailTasks[hash]
    }

    func loadSummary(_ hash: String, _ load: @escaping @Sendable () async throws -> CommitSummary) -> Task<Result<CommitSummary, Error>, Never> {
        if let task = summaryTasks[hash] { return task }
        let task = Task { [weak self] () -> Result<CommitSummary, Error> in
            let result: Result<CommitSummary, Error>
            do { result = .success(try await load()) } catch { result = .failure(error) }
            self?.finishSummary(hash, result)
            return result
        }
        summaryTasks[hash] = task
        touch(hash)
        return task
    }

    func loadDetail(_ hash: String, tabWidth: Int, _ load: @escaping @Sendable () async throws -> PreparedDetail) -> Task<Result<PreparedDetail, Error>, Never> {
        if let task = detailTasks[hash] { return task }
        let task = Task { [weak self] () -> Result<PreparedDetail, Error> in
            let result: Result<PreparedDetail, Error>
            do { result = .success(try await load()) } catch { result = .failure(error) }
            self?.finishDetail(hash, result)
            return result
        }
        detailTasks[hash] = task
        touch(hash)
        return task
    }

    func clearDetails() {
        details = [:]
        detailTasks = [:]
    }

    var pendingTasks: [Task<Void, Never>] {
        let summaries = summaryTasks.values.map { task in Task { _ = await task.value } }
        let details = detailTasks.values.map { task in Task { _ = await task.value } }
        return summaries + details + [hoverTask].compactMap { $0 }
    }

    private func finishSummary(_ hash: String, _ result: Result<CommitSummary, Error>) {
        summaryTasks[hash] = nil
        if case let .success(summary) = result, order.contains(hash) { summaries[hash] = summary }
    }

    private func finishDetail(_ hash: String, _ result: Result<PreparedDetail, Error>) {
        detailTasks[hash] = nil
        if case let .success(detail) = result, order.contains(hash) { details[hash] = detail }
    }

    private func touch(_ hash: String) {
        order.removeAll { $0 == hash }
        order.append(hash)
        while order.count > capacity {
            let evicted = order.removeFirst()
            summaries[evicted] = nil
            details[evicted] = nil
        }
    }
}
