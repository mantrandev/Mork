import MorkDomain
import Foundation
import Observation

@MainActor
@Observable
public final class CloneAccountsViewModel {
    private struct Listing {
        var repositories: [HostedRepository] = []
        var next: URL?
        var loadedFirstPage = false
    }

    public private(set) var accounts: [AccountEntry] = []
    public private(set) var selectedAccountID: String?
    public var query = ""
    public var usesSSH = false
    public private(set) var isLoading = false
    public private(set) var errorMessage: String?
    private var listings: [String: Listing] = [:]

    private let dependencies: AccountsDependencies

    public init(dependencies: AccountsDependencies) {
        self.dependencies = dependencies
    }

    public var hasAccounts: Bool { !accounts.isEmpty }
    public var selectedAccount: Account? { accounts.first { $0.id == selectedAccountID }?.account }
    public var repositories: [HostedRepository] { selectedAccountID.flatMap { listings[$0]?.repositories } ?? [] }
    public var hasMore: Bool { selectedAccountID.flatMap { listings[$0]?.next } != nil }

    public var filtered: [HostedRepository] {
        let needle = query.trimmingCharacters(in: .whitespaces)
        guard !needle.isEmpty else { return repositories }
        return repositories.filter { $0.fullName.localizedCaseInsensitiveContains(needle) || ($0.description?.localizedCaseInsensitiveContains(needle) ?? false) }
    }

    public func cloneURL(for repository: HostedRepository) -> String {
        repository.cloneURL(ssh: usesSSH)
    }

    public func load() async {
        accounts = await dependencies.loadAccounts.execute()
        if selectedAccount == nil {
            selectedAccountID = accounts.first { $0.status == .ready }?.id ?? accounts.first?.id
        }
        await loadFirstPageIfNeeded()
    }

    public func select(_ accountID: String?) async {
        selectedAccountID = accountID
        errorMessage = nil
        await loadFirstPageIfNeeded()
    }

    public func loadMore() async {
        guard let id = selectedAccountID, let next = listings[id]?.next else { return }
        await fetch(page: next, for: id)
    }

    public func retry() async {
        guard let id = selectedAccountID else { return }
        if listings[id]?.loadedFirstPage == true {
            await loadMore()
        } else {
            await fetch(page: nil, for: id)
        }
    }

    private func loadFirstPageIfNeeded() async {
        guard let id = selectedAccountID, listings[id]?.loadedFirstPage != true else { return }
        await fetch(page: nil, for: id)
    }

    private func fetch(page: URL?, for id: String) async {
        guard !isLoading, let account = accounts.first(where: { $0.id == id })?.account else { return }
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil
        do {
            let result = try await dependencies.loadRepositories.execute(account: account, page: page)
            var listing = listings[id] ?? Listing()
            listing.repositories += result.repositories
            listing.next = result.next
            listing.loadedFirstPage = true
            listings[id] = listing
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
