import MorkDomain
import Foundation

extension RepositoryViewModel {
    public func compareToLocalChanges(_ commit: Commit) -> LocalChangesComparisonViewModel {
        let session = LocalChangesComparisonViewModel(commit: commit, dependencies: dependencies.exploration.compare)
        session.load()
        return session
    }
}
