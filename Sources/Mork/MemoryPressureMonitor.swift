import Darwin
import Foundation

@MainActor
final class MemoryPressureMonitor {
    static let shared = MemoryPressureMonitor()
    static let didRaise = Notification.Name("MemoryPressureMonitor.didRaise")

    private var source: DispatchSourceMemoryPressure?

    func start() {
        guard source == nil else { return }
        let source = DispatchSource.makeMemoryPressureSource(eventMask: [.warning, .critical], queue: .main)
        source.setEventHandler {
            NotificationCenter.default.post(name: Self.didRaise, object: nil)
            malloc_zone_pressure_relief(nil, 0)
        }
        source.resume()
        self.source = source
    }
}
