import MorkDomain
import SwiftUI

struct SignatureBadge: View {
    let hash: String
    let store: SignatureBadgeStore

    var body: some View {
        if let status = store.status(of: hash), status != .none {
            SignatureIcon(status: status)
                .accessibilityIdentifier("signature.\(hash.prefix(7))")
        }
    }
}

struct SignatureIcon: View {
    let status: CommitSignature

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: Metrics.Icon.small, weight: .semibold))
            .foregroundStyle(color)
            .help("\(status.title): \(status.explanation)")
            .accessibilityLabel(status.title)
    }

    private var symbol: String {
        switch status {
        case .good: "checkmark.seal.fill"
        case .bad: "xmark.seal.fill"
        case .unknown, .none: "questionmark.diamond"
        }
    }

    private var color: Color {
        switch status {
        case .good: Palette.Status.added.ink.color
        case .bad: Palette.Status.deleted.ink.color
        case .unknown, .none: Palette.Status.conflict.ink.color
        }
    }
}
