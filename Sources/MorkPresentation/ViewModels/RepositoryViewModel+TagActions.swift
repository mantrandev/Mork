import MorkDomain
import Foundation

extension RepositoryViewModel {
    public var tagPushRemote: String? { remotes.first { $0.name == "origin" }?.name ?? remotes.first?.name }

    @discardableResult
    public func delete(_ tag: Tag, fromRemotes remoteNames: [String]) async -> Bool {
        await perform { dependencies in
            if !remoteNames.isEmpty { try await dependencies.tagActions.deleteFromRemotes.execute(tag: tag, remotes: remoteNames) }
            try await dependencies.deleteTag.execute(tag: tag)
        }
    }

    public func tagCommit(_ tag: Tag) async -> Commit? {
        do {
            return try await reading { try await dependencies.exploration.loadCommit.execute(revision: tag.reference + "^{commit}") }
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    public func tagDetails(_ tag: Tag) async throws -> String {
        try await reading { try await dependencies.tagActions.loadDetails.execute(tag: tag) }
    }

    public func merge(_ tag: Tag) async {
        await perform { try await $0.tagActions.merge.execute(tag: tag) }
    }

    public func rebase(onto tag: Tag) async {
        let current = currentBranch
        let autostash = hasUncommittedChanges
        await perform { try await $0.tagActions.rebase.execute(tag: tag, current: current, autostash: autostash) }
    }

    @discardableResult
    public func push(_ tag: Tag, to remote: String) async -> Bool {
        guard remotes.contains(where: { $0.name == remote }) else { return false }
        return await perform { try await $0.remoteOptions.pushTag.execute(name: tag.name, remotes: [remote]) }
    }
}
