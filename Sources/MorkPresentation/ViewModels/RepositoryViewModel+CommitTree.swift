import MorkDomain
import Foundation

extension RepositoryViewModel {
    public func browseFiles(at commit: Commit) {
        pane = .history
        reveal(commit)
        commitDetailsTab = .fileTree
    }

    public func openCommitFile(_ file: CommitFileChange, in commit: Commit) {
        let target = Selection.commitFile(commit, file)
        selection = target
        guard selection == target else { return }
        commitDetailsTab = .changes
    }

    public func selectParent(_ hash: String) async {
        pane = .history
        if let index = presentation.historyIndex[hash], historyRows.indices.contains(index) {
            reveal(historyRows[index].commit)
            return
        }
        let loadCommit = dependencies.exploration.loadCommit
        do {
            reveal(try await reading { try await loadCommit.execute(revision: hash) })
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func showFileTree() {
        guard let commit = selectedCommit else { return }
        if let fileTree {
            fileTree.show(commit)
            return
        }
        let tree = CommitTreeViewModel(commit: commit, dependencies: dependencies.exploration.tree) { [weak self] file in
            await self?.openFileInEditor(file)
        }
        fileTree = tree
        tree.show(commit)
    }

    public func waitForFileTree() async {
        await fileTree?.waitForLoads()
    }

    func openFileInEditor(_ file: URL) async {
        let settings = settings.integration
        do {
            try await dependencies.integration.openInApp.openFile(file.path, line: nil, settings: settings)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
