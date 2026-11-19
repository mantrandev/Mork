import Foundation

@MainActor
final class ExternalOpenQueue {
    static let shared = ExternalOpenQueue()

    private var pending: [ExternalOpenRequest] = []
    private var handler: (([ExternalOpenRequest]) -> Void)?

    func receive(_ urls: [URL]) {
        let requests = Self.unique(urls.compactMap(ExternalOpenRequest.init(url:)))
        guard !requests.isEmpty else { return }
        if let handler {
            handler(requests)
        } else {
            pending = Self.unique(pending + requests)
        }
    }

    func attach(_ handler: @escaping ([ExternalOpenRequest]) -> Void) {
        self.handler = handler
        let waiting = pending
        pending = []
        if !waiting.isEmpty { handler(waiting) }
    }

    nonisolated static func folder(for url: URL) -> URL {
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), !isDirectory.boolValue {
            return url.deletingLastPathComponent()
        }
        return url
    }

    private static func unique(_ requests: [ExternalOpenRequest]) -> [ExternalOpenRequest] {
        var seen: Set<ExternalOpenRequest> = []
        return requests.filter { seen.insert($0).inserted }
    }
}
