import MorkDomain
import SwiftUI

struct CloneAccountPicker: View {
    @Bindable var viewModel: CloneAccountsViewModel
    let pick: (String) -> Void
    @State private var chosen: String?

    var body: some View {
        if viewModel.hasAccounts {
            VStack(alignment: .leading, spacing: Metrics.Spacing.s) {
                DialogLabeledRow("Account") {
                    HStack(spacing: Metrics.Spacing.s) {
                        Picker("Account", selection: Binding(get: { viewModel.selectedAccountID }, set: { id in Task { await viewModel.select(id) } })) {
                            Text("None (type a URL)").tag(String?.none)
                            ForEach(viewModel.accounts) { entry in
                                Text("\(entry.account.login) · \(entry.account.server.displayName)").tag(Optional(entry.id))
                            }
                        }
                        .labelsHidden()
                        .accessibilityIdentifier("clone.account")
                        Picker("", selection: $viewModel.usesSSH) {
                            Text("HTTPS").tag(false)
                            Text("SSH").tag(true)
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .fixedSize()
                        .accessibilityIdentifier("clone.useSSH")
                        .onChange(of: viewModel.usesSSH) { _, _ in
                            if let repository = viewModel.repositories.first(where: { $0.id == chosen }) { pick(viewModel.cloneURL(for: repository)) }
                        }
                    }
                }
                if viewModel.selectedAccountID != nil {
                    DialogLabeledRow(nil) {
                        VStack(alignment: .leading, spacing: Metrics.Spacing.s) {
                            SearchField(prompt: "Search repositories", text: $viewModel.query, identifier: "clone.repoSearch")
                            List(selection: Binding(get: { chosen }, set: { id in
                                chosen = id
                                if let repository = viewModel.repositories.first(where: { $0.id == id }) { pick(viewModel.cloneURL(for: repository)) }
                            })) {
                                ForEach(viewModel.filtered) { repository in
                                    RepositoryRow(repository: repository)
                                        .tag(Optional(repository.id))
                                        .accessibilityIdentifier("clone.repo.\(repository.fullName)")
                                        .onAppear {
                                            if repository.id == viewModel.filtered.last?.id { Task { await viewModel.loadMore() } }
                                        }
                                }
                                if viewModel.isLoading {
                                    ProgressView().controlSize(.small).frame(maxWidth: .infinity)
                                } else if viewModel.hasMore {
                                    Button("Load More") { Task { await viewModel.loadMore() } }
                                        .buttonStyle(.mork(.secondary, size: .small))
                                        .accessibilityIdentifier("clone.loadMore")
                                }
                            }
                            .frame(height: Metrics.Sheet.cloneRepositoriesHeight)
                            .clipShape(RoundedRectangle(cornerRadius: Metrics.Radius.control, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: Metrics.Radius.control, style: .continuous).strokeBorder(Palette.Surface.borderStrong.color, lineWidth: Metrics.Line.hairline))
                            .accessibilityIdentifier("clone.repos")
                            if let error = viewModel.errorMessage {
                                HStack(spacing: Metrics.Spacing.s) {
                                    DialogNote(text: error, tone: .danger)
                                    Button("Retry") { Task { await viewModel.retry() } }
                                        .buttonStyle(.mork(.secondary, size: .small))
                                }
                                .accessibilityElement(children: .contain)
                                .accessibilityIdentifier("clone.accountError")
                            }
                        }
                    }
                }
            }
        }
    }
}

private struct RepositoryRow: View {
    let repository: HostedRepository

    var body: some View {
        HStack(spacing: Metrics.ChangeRow.gap) {
            Image(systemName: repository.isPrivate ? "lock.fill" : "book.closed")
                .font(.system(size: Metrics.Icon.small))
                .foregroundStyle(Palette.Text.secondary.color)
            VStack(alignment: .leading, spacing: Metrics.Spacing.xxs) {
                Text(repository.fullName)
                    .font(Metrics.Font.title)
                    .foregroundStyle(Palette.Text.primary.color)
                if let description = repository.description {
                    Text(description)
                        .font(Metrics.Font.caption)
                        .foregroundStyle(Palette.Text.secondary.color)
                        .lineLimit(1)
                }
            }
        }
    }
}
