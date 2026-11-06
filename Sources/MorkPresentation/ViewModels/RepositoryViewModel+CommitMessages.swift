import MorkDomain
import Foundation

extension RepositoryViewModel {
    public func requestMessage(for hash: String) {
        guard commitMessages.request(hash), commitMessages.task == nil else { return }
        let load = dependencies.commit.loadCommitMessages
        let sleep = sleep
        let store = commitMessages
        store.task = Task {
            defer { store.task = nil }
            try? await sleep(CommitMessageStore.debounce)
            while !Task.isCancelled {
                let batch = store.takePending(limit: LoadCommitMessagesUseCase.batchLimit)
                guard !batch.isEmpty else { return }
                let results = (try? await load.execute(hashes: batch)) ?? [:]
                guard !Task.isCancelled else { return }
                store.store(results)
            }
        }
    }

    public func waitForMessages() async {
        while let task = commitMessages.task {
            await task.value
        }
    }

    public func displayedMessage(of commit: Commit) -> String {
        if case let .loaded(summary) = commitInfo, summary.commit == commit { return summary.message }
        return commitMessages.message(of: commit.hash) ?? commit.subject
    }
}
