import MorkDomain
import Foundation

extension RepositoryViewModel {
    public func requestSignature(for hash: String) {
        guard signatureBadges.request(hash), signatureBadges.task == nil else { return }
        let load = dependencies.commit.loadCommitSignatures
        let sleep = sleep
        let store = signatureBadges
        store.task = Task {
            defer { store.task = nil }
            try? await sleep(SignatureBadgeStore.debounce)
            while !Task.isCancelled {
                let batch = store.takePending(limit: LoadCommitSignaturesUseCase.batchLimit)
                guard !batch.isEmpty else { return }
                let results = (try? await load.execute(hashes: batch)) ?? [:]
                guard !Task.isCancelled else { return }
                store.store(results, for: batch)
            }
        }
    }

    public func waitForSignatures() async {
        while let task = signatureBadges.task {
            await task.value
        }
    }
}
