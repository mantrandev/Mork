import Foundation

public protocol DetectIntegrationsUseCaseProtocol: Sendable {
    func execute(rescan: Bool) async -> IntegrationInventory
}

public final class DetectIntegrationsUseCase: DetectIntegrationsUseCaseProtocol {
    private actor Cache {
        private var detection: Task<IntegrationInventory, Never>?

        func inventory(rescan: Bool, detect: @escaping @Sendable () async -> IntegrationInventory) -> Task<IntegrationInventory, Never> {
            if !rescan, let detection { return detection }
            let task = Task { await detect() }
            detection = task
            return task
        }
    }

    private let detector: IntegrationDetectorProtocol
    private let cache = Cache()

    public init(detector: IntegrationDetectorProtocol) {
        self.detector = detector
    }

    public func execute(rescan: Bool) async -> IntegrationInventory {
        let detector = detector
        return await cache.inventory(rescan: rescan) { await detector.detect() }.value
    }
}
