import Foundation

@MainActor
final class ExternalOpenQueue {
    static let shared = ExternalOpenQueue()

    private var pending: [URL] = []
    private var handler: (([URL]) -> Void)?

    func receive(_ urls: [URL]) {
        let folders = Self.unique(urls.filter(\.isFileURL).map(Self.folder))
        guard !folders.isEmpty else { return }
        if let handler {
            handler(folders)
        } else {
            pending = Self.unique(pending + folders)
        }
    }

    func attach(_ handler: @escaping ([URL]) -> Void) {
        self.handler = handler
        let waiting = pending
        pending = []
        if !waiting.isEmpty { handler(waiting) }
    }

    static func folder(for url: URL) -> URL {
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), !isDirectory.boolValue {
            return url.deletingLastPathComponent()
        }
        return url
    }

    private static func unique(_ urls: [URL]) -> [URL] {
        var seen: Set<String> = []
        return urls.filter { seen.insert($0.standardizedFileURL.path).inserted }
    }
}
