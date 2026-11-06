import MorkDomain
import Foundation

extension RepositoryViewModel {
    public func showTreemap() async {
        let session = TreemapViewModel(repositoryName: name, changedPaths: Set(changes.map(\.path)), loadTreemap: dependencies.advanced.loadTreemap)
        advanced.treemap = session
        await session.load()
    }

    public func fileURL(of path: String) -> URL {
        url.appendingPathComponent(path)
    }

    @discardableResult
    public func showInChanges(_ path: String) -> Bool {
        let target: Selection? = if let change = unstagedChanges.first(where: { $0.path == path }) {
            .file(change, staged: false)
        } else if let change = stagedChanges.first(where: { $0.path == path }) {
            .file(change, staged: true)
        } else {
            nil
        }
        guard let target else { return false }
        advanced.treemap = nil
        pane = .changes
        selection = target
        return true
    }
}
