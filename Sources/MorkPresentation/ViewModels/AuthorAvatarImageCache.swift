import MorkDomain
import CoreGraphics
import Foundation
import Observation

@MainActor
@Observable
public final class AuthorAvatarImageCache {
    public static let memoryCostLimit = 32 << 20
    public static let memoryCountLimit = 2_000

    public var isEnabled: Bool

    @ObservationIgnored private let load: @Sendable (String) async -> Data?
    @ObservationIgnored private let memory = NSCache<NSString, CachedImage>()
    @ObservationIgnored private var dataLoads: [String: Task<Data?, Never>] = [:]
    @ObservationIgnored private var imageLoads: [String: Task<CGImage?, Never>] = [:]
    @ObservationIgnored private var failures: Set<String> = []

    public init(isEnabled: Bool = true, load: @escaping @Sendable (String) async -> Data?) {
        self.isEnabled = isEnabled
        self.load = load
        memory.totalCostLimit = Self.memoryCostLimit
        memory.countLimit = Self.memoryCountLimit
    }

    public func cachedImage(for email: String, pixelSize: Int) -> CGImage? {
        memory.object(forKey: Self.key(AvatarLocator.normalizedEmail(email), pixelSize))?.image
    }

    public func hasFailed(_ email: String) -> Bool {
        failures.contains(AvatarLocator.normalizedEmail(email))
    }

    public func image(for email: String, pixelSize: Int) async -> CGImage? {
        let email = AvatarLocator.normalizedEmail(email)
        guard isEnabled, !email.isEmpty, !failures.contains(email) else { return nil }
        let key = Self.key(email, pixelSize)
        if let cached = memory.object(forKey: key) { return cached.image }
        if let running = imageLoads[key as String] { return await running.value }
        let task = Task { await self.fetch(email, pixelSize: pixelSize, key: key) }
        imageLoads[key as String] = task
        return await task.value
    }

    private func fetch(_ email: String, pixelSize: Int, key: NSString) async -> CGImage? {
        defer { imageLoads[key as String] = nil }
        guard let data = await data(for: email), let image = await AvatarDecoder.decode(data, maxPixelSize: pixelSize) else {
            failures.insert(email)
            return nil
        }
        memory.setObject(CachedImage(image), forKey: key, cost: image.bytesPerRow * image.height)
        return image
    }

    private func data(for email: String) async -> Data? {
        if let running = dataLoads[email] { return await running.value }
        let load = load
        let task = Task.detached(priority: .utility) { await load(email) }
        dataLoads[email] = task
        let data = await task.value
        dataLoads[email] = nil
        return data
    }

    private static func key(_ email: String, _ pixelSize: Int) -> NSString {
        "\(pixelSize) \(email)" as NSString
    }
}

private final class CachedImage {
    let image: CGImage

    init(_ image: CGImage) {
        self.image = image
    }
}
