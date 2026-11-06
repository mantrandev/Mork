import SwiftUI

struct EmptyStateView<Actions: View>: View {
    let title: String
    let systemImage: String
    var message: String?
    private let hasActions: Bool
    private let actions: Actions

    init(_ title: String, systemImage: String, message: String? = nil, @ViewBuilder actions: () -> Actions) {
        self.title = title
        self.systemImage = systemImage
        self.message = message
        self.actions = actions()
        hasActions = true
    }

    var body: some View {
        VStack(spacing: Metrics.Spacing.xs + Metrics.Spacing.xxs) {
            Image(systemName: systemImage)
                .font(.system(size: Metrics.EmptyState.glyph))
                .foregroundStyle(Palette.Text.tertiary.color)
                .accessibilityHidden(true)
            Text(title)
                .font(Metrics.Font.title.weight(.semibold))
                .foregroundStyle(Palette.Text.primary.color)
            if let message {
                Text(message)
                    .font(Metrics.Font.body)
                    .foregroundStyle(Palette.Text.secondary.color)
                    .frame(maxWidth: Metrics.EmptyState.messageWidth)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if hasActions {
                actions
                    .padding(.top, Metrics.Spacing.xs)
            }
        }
        .multilineTextAlignment(.center)
        .padding(Metrics.Spacing.l)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: hasActions ? .contain : .combine)
    }
}

extension EmptyStateView where Actions == EmptyView {
    init(_ title: String, systemImage: String, message: String? = nil) {
        self.title = title
        self.systemImage = systemImage
        self.message = message
        actions = EmptyView()
        hasActions = false
    }
}
