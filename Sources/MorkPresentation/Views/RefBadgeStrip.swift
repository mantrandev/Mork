import SwiftUI

struct RefBadgeStrip: View {
    let labels: [RefLabel]
    let lane: Int

    var body: some View {
        ViewThatFits(in: .horizontal) {
            ForEach(Array(Self.candidates(labels).enumerated()), id: \.offset) { _, candidate in
                HStack(spacing: Metrics.Spacing.xs) {
                    ForEach(candidate, id: \.self) { RefBadge(label: $0, lane: lane).fixedSize() }
                }
            }
        }
        .clipped()
    }

    nonisolated static func candidates(_ labels: [RefLabel]) -> [[RefLabel]] {
        stride(from: labels.count, through: 1, by: -1).map { kept in
            let hidden = labels.dropFirst(kept)
            guard !hidden.isEmpty else { return labels }
            let names = hidden.flatMap { [$0.name] + $0.others }
            return Array(labels.prefix(kept)) + [RefLabel(kind: .more, name: "+\(names.count)", others: names)]
        }
    }
}

struct HistoryMessageLayout: Layout {
    let spacing: CGFloat

    static func badgesWidth(available: CGFloat, badgesIdeal: CGFloat, restIdeal: CGFloat, spacing: CGFloat) -> CGFloat {
        let room = max(available * Metrics.HistoryPane.badgeShare, available - restIdeal - spacing)
        return max(0, min(badgesIdeal, room, available))
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard subviews.count == 2 else { return .zero }
        let badges = subviews[0].sizeThatFits(.unspecified)
        let rest = subviews[1].sizeThatFits(.unspecified)
        let height = max(badges.height, rest.height)
        return CGSize(width: proposal.width ?? badges.width + spacing + rest.width, height: proposal.height ?? height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard subviews.count == 2 else { return }
        let badges = Self.badgesWidth(
            available: bounds.width,
            badgesIdeal: subviews[0].sizeThatFits(.unspecified).width,
            restIdeal: subviews[1].sizeThatFits(.unspecified).width,
            spacing: spacing
        )
        subviews[0].place(at: CGPoint(x: bounds.minX, y: bounds.midY), anchor: .leading, proposal: ProposedViewSize(width: badges, height: bounds.height))
        let restX = bounds.minX + (badges > 0 ? badges + spacing : 0)
        subviews[1].place(at: CGPoint(x: restX, y: bounds.midY), anchor: .leading, proposal: ProposedViewSize(width: max(0, bounds.maxX - restX), height: bounds.height))
    }
}
