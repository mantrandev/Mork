import Foundation

public struct ChangeDebouncer<Instant: InstantProtocol>: Sendable where Instant.Duration == Duration {
    public let quietPeriod: Duration
    public let maximumDelay: Duration
    private var firstChange: Instant?
    private var lastChange: Instant?

    public init(quietPeriod: Duration = .milliseconds(150), maximumDelay: Duration = .seconds(1)) {
        self.quietPeriod = quietPeriod
        self.maximumDelay = maximumDelay
    }

    public var isPending: Bool { firstChange != nil }

    public var deadline: Instant? {
        guard let firstChange, let lastChange else { return nil }
        return min(lastChange.advanced(by: quietPeriod), firstChange.advanced(by: maximumDelay))
    }

    public mutating func receive(at now: Instant) {
        if firstChange == nil { firstChange = now }
        lastChange = now
    }

    public mutating func fire(at now: Instant) -> Bool {
        guard let deadline, now >= deadline else { return false }
        firstChange = nil
        lastChange = nil
        return true
    }
}
