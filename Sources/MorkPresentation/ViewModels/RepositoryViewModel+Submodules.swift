import MorkDomain
import Foundation

extension RepositoryViewModel {
    nonisolated static func submoduleSummary(of text: String, path: String?) -> String? {
        guard let path, let diff = SubmoduleDiff.parse(text) else { return nil }
        return diff.summary(path: path)
    }

    public func url(of submodule: Submodule) -> URL {
        url.appendingPathComponent(submodule.path)
    }

    public func updateSubmodules() async {
        guard !submoduleUpdate.isRunning else { return }
        submoduleUpdate = SubmoduleUpdate()
        submoduleUpdate.isRunning = true
        defer { submoduleUpdate.isRunning = false }
        let (lines, continuation) = AsyncStream<String>.makeStream()
        let update = dependencies.workspace.submodules.updateSubmodules
        let task = Task {
            defer { continuation.finish() }
            try await update.execute { continuation.yield($0) }
        }
        for await line in lines {
            submoduleUpdate.progress.append(line)
        }
        await perform { _ in try await task.value }
    }

    @discardableResult
    public func addSubmodule(url: String, path: String) async -> Bool {
        await perform { try await $0.workspace.submodules.addSubmodule.execute(url: url, path: path) }
    }

    public func syncSubmodules() async {
        await perform { try await $0.workspace.submodules.syncSubmodules.execute() }
    }

    var selectedFilePath: String? {
        switch selection {
        case let .file(change, _): change.path
        case let .commitFile(_, file): file.path
        case .commit, nil: nil
        }
    }
}
