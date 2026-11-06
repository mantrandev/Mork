import MorkDomain

extension HistoryRepositoryImpl {
    func markingSyncStatus(_ commits: [Commit]) async throws -> [Commit] {
        guard !commits.isEmpty else { return commits }
        return try await markingSyncStatus(commits, branches: BranchRepositoryImpl(executor: executor).branches())
    }

    public func markingSyncStatus(_ commits: [Commit], branches: [Branch]) async throws -> [Commit] {
        guard !commits.isEmpty else { return commits }
        guard let current = branches.first(where: \.isCurrent),
              !current.isUpstreamGone, let upstream = current.upstream,
              let remote = branches.first(where: { $0.isRemote && $0.name == upstream }) else { return commits }
        let candidates = Set(commits.flatMap { ["<" + $0.hash, ">" + $0.hash] })
        let differences = try await executor.readLines(
            ["rev-list", "--left-right", "\(current.fullName)...\(remote.fullName)"], matching: candidates
        )
        let localOnly = Set(differences.filter { $0.hasPrefix("<") }.map { String($0.dropFirst()) })
        let remoteOnly = Set(differences.filter { $0.hasPrefix(">") }.map { String($0.dropFirst()) })
        return commits.map { commit in
            var marked = commit
            if localOnly.contains(commit.hash) {
                marked.syncStatus = .localOnly
            } else if remoteOnly.contains(commit.hash) {
                marked.syncStatus = .remoteOnly
            }
            return marked
        }
    }
}
