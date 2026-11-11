import SwiftUI

struct RefBadgeStrip: View {
    let labels: [RefLabel]
    let lane: Int
    let menus: HistoryRefMenus

    var body: some View {
        RefBadgeStripLayout(count: labels.count, spacing: Metrics.Spacing.xs, minimum: Metrics.Badge.minimumWidth) {
            ForEach(labels, id: \.self) { badge($0) }
            ForEach(1..<max(labels.count, 1), id: \.self) { kept in
                badge(Self.overflow(labels, keeping: kept))
            }
        }
        .clipped()
    }

    @ViewBuilder
    private func badge(_ label: RefLabel) -> some View {
        if RefBadgePopover.names(of: label).isEmpty {
            RefBadge(label: label, lane: lane)
        } else {
            RefBadgeButton(label: label, lane: lane, menus: menus)
        }
    }

    nonisolated static func overflow(_ labels: [RefLabel], keeping kept: Int) -> RefLabel {
        let names = labels.dropFirst(kept).flatMap { [$0.name] + $0.others }
        return RefLabel(kind: .more, name: "+\(names.count)", others: names)
    }
}

struct RefBadgeStripLayout: Layout {
    struct Plan: Equatable {
        let visible: Int
        let widths: [CGFloat]
        let overflow: CGFloat?
        let spacing: CGFloat

        var used: CGFloat {
            guard visible > 0 else { return 0 }
            return widths.reduce(0, +) + spacing * CGFloat(visible - 1) + (overflow.map { $0 + spacing } ?? 0)
        }
    }

    let count: Int
    let spacing: CGFloat
    let minimum: CGFloat

    static func plan(ideals: [CGFloat], overflows: [CGFloat], minimum: CGFloat, spacing: CGFloat, available: CGFloat) -> Plan {
        let total = ideals.count
        for kept in stride(from: total, through: 1, by: -1) {
            let overflow = kept < total ? overflows[kept - 1] : nil
            let extra = overflow.map { $0 + spacing } ?? 0
            let gaps = spacing * CGFloat(kept - 1)
            let shown = Array(ideals.prefix(kept))
            let floors = shown.map { min($0, minimum) }
            guard floors.reduce(0, +) + gaps + extra <= available || kept == 1 else { continue }
            let room = max(0, available - gaps - extra)
            return Plan(visible: kept, widths: fit(shown, floors: floors, room: room), overflow: overflow, spacing: spacing)
        }
        return Plan(visible: 0, widths: [], overflow: nil, spacing: spacing)
    }

    private static func fit(_ ideals: [CGFloat], floors: [CGFloat], room: CGFloat) -> [CGFloat] {
        guard ideals.reduce(0, +) > room else { return ideals }
        let floorSum = floors.reduce(0, +)
        guard floorSum < room else { return floors.map { floorSum > 0 ? $0 * room / floorSum : 0 } }
        func width(at cap: CGFloat) -> CGFloat {
            ideals.indices.reduce(0) { $0 + max(floors[$1], min(ideals[$1], cap)) }
        }
        var low: CGFloat = 0
        var high = ideals.max() ?? 0
        for _ in 0..<40 {
            let middle = (low + high) / 2
            if width(at: middle) > room { high = middle } else { low = middle }
        }
        return ideals.indices.map { max(floors[$0], min(ideals[$0], low)) }
    }

    private func plan(for subviews: Subviews, available: CGFloat) -> Plan {
        let ideals = subviews.prefix(count).map { $0.sizeThatFits(.unspecified).width }
        let overflows = subviews.dropFirst(count).map { $0.sizeThatFits(.unspecified).width }
        return Self.plan(ideals: ideals, overflows: overflows, minimum: minimum, spacing: spacing, available: available)
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let height = subviews.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0
        let width = plan(for: subviews, available: proposal.width ?? .infinity).used
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let plan = plan(for: subviews, available: bounds.width)
        var x = bounds.minX
        for index in subviews.indices {
            let width: CGFloat?
            if index < plan.visible {
                width = plan.widths[index]
            } else if let overflow = plan.overflow, index == count + plan.visible - 1 {
                width = overflow
            } else {
                width = nil
            }
            guard let width else {
                subviews[index].place(at: CGPoint(x: bounds.maxX, y: bounds.midY), anchor: .leading, proposal: .zero)
                continue
            }
            subviews[index].place(at: CGPoint(x: x, y: bounds.midY), anchor: .leading, proposal: ProposedViewSize(width: width, height: bounds.height))
            x += width + spacing
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
        let room = Self.badgesWidth(
            available: bounds.width,
            badgesIdeal: subviews[0].sizeThatFits(.unspecified).width,
            restIdeal: subviews[1].sizeThatFits(.unspecified).width,
            spacing: spacing
        )
        let badges = min(room, subviews[0].sizeThatFits(ProposedViewSize(width: room, height: bounds.height)).width)
        subviews[0].place(at: CGPoint(x: bounds.minX, y: bounds.midY), anchor: .leading, proposal: ProposedViewSize(width: badges, height: bounds.height))
        let restX = bounds.minX + (badges > 0 ? badges + spacing : 0)
        subviews[1].place(at: CGPoint(x: restX, y: bounds.midY), anchor: .leading, proposal: ProposedViewSize(width: max(0, bounds.maxX - restX), height: bounds.height))
    }
}
