import Foundation

extension AppViewModel {
    public func droppableFolders(_ urls: [URL]) async -> [URL] {
        var folders: [URL] = []
        for url in urls {
            if let folder = await droppableFolder(url) { folders.append(folder) }
        }
        return folders
    }

    @discardableResult
    public func openDropped(_ urls: [URL]) async -> Int {
        let folders = await droppableFolders(urls)
        for folder in folders { await open(folder) }
        return folders.count
    }

    private func droppableFolder(_ url: URL) async -> URL? {
        guard url.isFileURL, let isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory else { return nil }
        if isDirectory { return url }
        let parent = url.deletingLastPathComponent()
        return (try? await dependencies.locateRepository.execute(url: parent)) == nil ? nil : parent
    }
}
