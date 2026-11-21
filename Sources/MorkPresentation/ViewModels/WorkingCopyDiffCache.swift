import MorkDomain
import Foundation

@MainActor
final class WorkingCopyDiffCache {
    struct Key: Hashable, Sendable {
        let change: FileChange
        let staged: Bool
    }

    typealias Loaded = RepositoryViewModel.LoadedDetail

    let capacity: Int
    let byteBudget: Int
    private var entries: [Key: Loaded] = [:]
    private var oversized: Set<Key> = []
    private var tasks: [Key: Task<Loaded, Never>] = [:]
    private var order: [Key] = []
    private var generation = 0
    var hoverTask: Task<Void, Never>?

    init(capacity: Int, byteBudget: Int) {
        self.capacity = capacity
        self.byteBudget = byteBudget
    }

    func detail(of key: Key) -> Loaded? {
        entries[key]
    }

    func isKnown(_ key: Key) -> Bool {
        entries[key] != nil || tasks[key] != nil || oversized.contains(key)
    }

    func load(_ key: Key, _ body: @escaping @Sendable () async -> Loaded) -> Task<Loaded, Never> {
        if let task = tasks[key] { return task }
        let generation = generation
        let task = Task { [weak self] () -> Loaded in
            let loaded = await body()
            self?.finish(key, loaded, generation: generation)
            return loaded
        }
        tasks[key] = task
        return task
    }

    func clear() {
        generation &+= 1
        entries = [:]
        tasks = [:]
        order = []
        oversized = []
    }

    var pendingTasks: [Task<Void, Never>] {
        tasks.values.map { task in Task { _ = await task.value } } + [hoverTask].compactMap { $0 }
    }

    private func finish(_ key: Key, _ loaded: Loaded, generation: Int) {
        guard generation == self.generation else { return }
        tasks[key] = nil
        guard case .loaded = loaded.result else { return }
        let cost = loaded.cost
        guard cost <= byteBudget else {
            oversized.insert(key)
            return
        }
        entries[key] = loaded
        order.removeAll { $0 == key }
        order.append(key)
        var total = order.reduce(0) { $0 + (entries[$1]?.cost ?? 0) }
        while order.count > capacity || total > byteBudget {
            total -= entries.removeValue(forKey: order.removeFirst())?.cost ?? 0
        }
    }
}

extension RepositoryViewModel.LoadedDetail {
    var cost: Int {
        guard case let .loaded(text) = result else { return 0 }
        let bytes = text.utf8.count
        return bytes + (prepared?.patch == nil ? 0 : bytes) + (prepared?.document.cost ?? 0)
    }
}
