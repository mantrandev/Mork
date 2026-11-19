import Foundation
import MorkPresentation

struct ExternalOpenRequest: Hashable {
    enum View: Hashable {
        case repository
        case changes
        case history
        case fileHistory(path: String)
    }

    static let scheme = "mork"

    let folder: URL
    let view: View

    init(folder: URL, view: View = .repository) {
        self.folder = URL(fileURLWithPath: folder.standardizedFileURL.path, isDirectory: true)
        self.view = view
    }

    init?(url: URL) {
        if url.isFileURL {
            self.init(folder: ExternalOpenQueue.folder(for: url))
            return
        }
        guard url.scheme == Self.scheme, url.host == "open",
              let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
              let path = items.first(where: { $0.name == "path" })?.value, path.hasPrefix("/")
        else { return nil }
        let file = items.first(where: { $0.name == "file" })?.value
        switch items.first(where: { $0.name == "view" })?.value {
        case "changes":
            self.init(folder: URL(fileURLWithPath: path), view: .changes)
        case "history":
            if let file, file.hasPrefix("/") {
                self.init(folder: URL(fileURLWithPath: path), view: .fileHistory(path: URL(fileURLWithPath: file).standardizedFileURL.path))
            } else {
                self.init(folder: URL(fileURLWithPath: path), view: .history)
            }
        default:
            return nil
        }
    }
}

extension AppViewModel {
    func open(_ request: ExternalOpenRequest) async {
        await open(request.folder)
        guard request.view != .repository, let repository else { return }
        let root = Self.resolved(repository.url.path)
        guard Self.relativePath(of: Self.resolved(request.folder.path), in: root) != nil else { return }
        switch request.view {
        case .repository:
            return
        case .changes:
            repository.pane = .changes
        case .history:
            repository.pane = .history
        case let .fileHistory(path):
            repository.pane = .history
            guard let file = Self.relativePath(of: Self.resolved(path), in: root), !file.isEmpty else { return }
            repository.showFileHistory(path: file)
        }
    }

    nonisolated static func relativePath(of path: String, in root: String) -> String? {
        if path == root { return "" }
        let prefix = root.hasSuffix("/") ? root : root + "/"
        guard path.hasPrefix(prefix) else { return nil }
        return String(path.dropFirst(prefix.count))
    }

    private nonisolated static func resolved(_ path: String) -> String {
        let url = URL(fileURLWithPath: path)
        return url.deletingLastPathComponent().resolvingSymlinksInPath().appendingPathComponent(url.lastPathComponent).standardizedFileURL.path
    }
}
