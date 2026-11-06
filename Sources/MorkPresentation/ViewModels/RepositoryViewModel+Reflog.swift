import MorkDomain
import Foundation

extension RepositoryViewModel {
    public func loadReflog() async {
        if case .loaded = reflog {} else { reflog = .loading }
        do {
            reflog = .loaded(try await dependencies.exploration.loadReflog.execute(limit: Self.historyLimit))
        } catch {
            reflog = .failed(error.localizedDescription)
        }
    }

    public func select(_ entry: ReflogEntry) {
        selection = .commit(entry.commit)
    }
}
