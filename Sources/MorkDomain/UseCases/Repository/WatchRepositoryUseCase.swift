import Foundation

public protocol WatchRepositoryUseCaseProtocol: Sendable {
    func execute(root: URL) -> AsyncStream<Void>
}

public final class WatchRepositoryUseCase<C: Clock>: WatchRepositoryUseCaseProtocol where C.Duration == Duration {
    public let quietPeriod: Duration
    public let maximumDelay: Duration
    private let watcher: RepositoryWatcherProtocol
    private let clock: C

    public init(watcher: RepositoryWatcherProtocol, clock: C, quietPeriod: Duration = .milliseconds(150), maximumDelay: Duration = .seconds(1)) {
        self.watcher = watcher
        self.clock = clock
        self.quietPeriod = quietPeriod
        self.maximumDelay = maximumDelay
    }

    public func execute(root: URL) -> AsyncStream<Void> {
        let (stream, continuation) = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))
        let coalescer = Coalescer(clock: clock, debouncer: ChangeDebouncer(quietPeriod: quietPeriod, maximumDelay: maximumDelay), continuation: continuation)
        let changes = watcher.changes(in: root)
        let task = Task {
            for await paths in changes where RepositoryChangeFilter.containsRelevantChange(paths) {
                await coalescer.receive()
            }
            await coalescer.finish()
        }
        continuation.onTermination = { _ in task.cancel() }
        return stream
    }
}

extension WatchRepositoryUseCase where C == ContinuousClock {
    public convenience init(watcher: RepositoryWatcherProtocol) {
        self.init(watcher: watcher, clock: ContinuousClock())
    }
}

private actor Coalescer<C: Clock> where C.Duration == Duration {
    private let clock: C
    private var debouncer: ChangeDebouncer<C.Instant>
    private let continuation: AsyncStream<Void>.Continuation
    private var timer: Task<Void, Never>?

    init(clock: C, debouncer: ChangeDebouncer<C.Instant>, continuation: AsyncStream<Void>.Continuation) {
        self.clock = clock
        self.debouncer = debouncer
        self.continuation = continuation
    }

    func receive() {
        debouncer.receive(at: clock.now)
        schedule()
    }

    func finish() {
        timer?.cancel()
        if debouncer.isPending { continuation.yield() }
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
        if debouncer.fire(at: clock.now) {
            continuation.yield()
        } else {
            schedule()
        }
    }
}
