import Foundation

public protocol WatchRepositoryUseCaseProtocol: Sendable {
    func execute(root: URL) -> AsyncStream<Void>
}

public final class WatchRepositoryUseCase<C: Clock>: WatchRepositoryUseCaseProtocol where C.Duration == Duration {
    public let quietPeriod: Duration
    public let maximumDelay: Duration
    public let pathLimit: Int
    private let watcher: RepositoryWatcherProtocol
    private let ignoredPaths: IgnoredPathsRepositoryProtocol
    private let clock: C

    public init(
        watcher: RepositoryWatcherProtocol,
        ignoredPaths: IgnoredPathsRepositoryProtocol,
        clock: C,
        quietPeriod: Duration = .milliseconds(150),
        maximumDelay: Duration = .seconds(1),
        pathLimit: Int = RepositoryChanges.limit
    ) {
        self.watcher = watcher
        self.ignoredPaths = ignoredPaths
        self.clock = clock
        self.quietPeriod = quietPeriod
        self.maximumDelay = maximumDelay
        self.pathLimit = pathLimit
    }

    public func execute(root: URL) -> AsyncStream<Void> {
        let (stream, continuation) = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))
        let coalescer = Coalescer(
            clock: clock,
            debouncer: ChangeDebouncer(quietPeriod: quietPeriod, maximumDelay: maximumDelay),
            pending: PendingChanges(limit: pathLimit),
            ignoredPaths: ignoredPaths,
            continuation: continuation
        )
        let changes = watcher.changes(in: root)
        let task = Task {
            for await batch in changes {
                switch batch {
                case .many:
                    await coalescer.receive(.many)
                case .paths(let paths):
                    let relevant = paths.filter(RepositoryChangeFilter.isRelevant)
                    if !relevant.isEmpty { await coalescer.receive(.paths(relevant)) }
                }
            }
            await coalescer.finish()
        }
        continuation.onTermination = { _ in task.cancel() }
        return stream
    }
}

extension WatchRepositoryUseCase where C == ContinuousClock {
    public convenience init(watcher: RepositoryWatcherProtocol, ignoredPaths: IgnoredPathsRepositoryProtocol) {
        self.init(watcher: watcher, ignoredPaths: ignoredPaths, clock: ContinuousClock())
    }
}

private struct PendingChanges {
    let limit: Int
    private(set) var workTreePaths: Set<String> = []
    private(set) var needsRefresh = false

    init(limit: Int) {
        self.limit = limit
    }

    mutating func add(_ changes: RepositoryChanges) {
        guard !needsRefresh else { return }
        guard case .paths(let paths) = changes else { return markRefresh() }
        for path in paths {
            guard RepositoryChangeFilter.needsIgnoreCheck(path) else { return markRefresh() }
            workTreePaths.insert(path)
        }
        if workTreePaths.count > limit { markRefresh() }
    }

    mutating func take() -> PendingChanges {
        defer { self = PendingChanges(limit: limit) }
        return self
    }

    private mutating func markRefresh() {
        needsRefresh = true
        workTreePaths = []
    }
}

private actor Coalescer<C: Clock> where C.Duration == Duration {
    private let clock: C
    private var debouncer: ChangeDebouncer<C.Instant>
    private var pending: PendingChanges
    private let ignoredPaths: IgnoredPathsRepositoryProtocol
    private let continuation: AsyncStream<Void>.Continuation
    private var timer: Task<Void, Never>?
    private var check: Task<Void, Never>?

    init(clock: C, debouncer: ChangeDebouncer<C.Instant>, pending: PendingChanges, ignoredPaths: IgnoredPathsRepositoryProtocol, continuation: AsyncStream<Void>.Continuation) {
        self.clock = clock
        self.debouncer = debouncer
        self.pending = pending
        self.ignoredPaths = ignoredPaths
        self.continuation = continuation
    }

    func receive(_ changes: RepositoryChanges) {
        pending.add(changes)
        debouncer.receive(at: clock.now)
        schedule()
    }

    func finish() async {
        timer?.cancel()
        await check?.value
        if debouncer.isPending, await shouldRefresh(pending.take()) { continuation.yield() }
        continuation.finish()
    }

    private func schedule() {
        timer?.cancel()
        guard let deadline = debouncer.deadline else { return }
        let clock = clock
        timer = Task {
            do {
                try await clock.sleep(until: deadline, tolerance: nil)
            } catch {
                return
            }
            self.fire()
        }
    }

    private func fire() {
        guard debouncer.fire(at: clock.now) else { return schedule() }
        let changes = pending.take()
        let previous = check
        check = Task {
            await previous?.value
            if await shouldRefresh(changes) { continuation.yield() }
        }
    }

    private func shouldRefresh(_ changes: PendingChanges) async -> Bool {
        if changes.needsRefresh { return true }
        guard !changes.workTreePaths.isEmpty else { return false }
        guard let ignored = try? await ignoredPaths.ignoredPaths(changes.workTreePaths.sorted()) else { return true }
        return !changes.workTreePaths.isSubset(of: ignored)
    }
}
