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
    private var entries: [Key: Loaded] = [:]
    private var tasks: [Key: Task<Loaded, Never>] = [:]
    private var order: [Key] = []
    private var generation = 0
    var hoverTask: Task<Void, Never>?

    init(capacity: Int) {
        self.capacity = capacity
    }

    func detail(of key: Key) -> Loaded? {
        entries[key]
    }

    func isKnown(_ key: Key) -> Bool {
        entries[key] != nil || tasks[key] != nil
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
    }

    var pendingTasks: [Task<Void, Never>] {
        tasks.values.map { task in Task { _ = await task.value } } + [hoverTask].compactMap { $0 }
    }

    private func finish(_ key: Key, _ loaded: Loaded, generation: Int) {
        guard generation == self.generation else { return }
        tasks[key] = nil
        guard case .loaded = loaded.result else { return }
        entries[key] = loaded
        order.removeAll { $0 == key }
        order.append(key)
        while order.count > capacity {
            entries[order.removeFirst()] = nil
        }
    }
}
