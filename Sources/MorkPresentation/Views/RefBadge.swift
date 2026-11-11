import SwiftUI

struct RefBadge: View {
    let label: RefLabel
    let lane: Int

    private var isCurrent: Bool { label.kind == .currentBranch }
    private var isDetached: Bool { label.kind == .detachedHead }
    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: Metrics.Radius.badge, style: .continuous) }

    var body: some View {
        let ink = Self.ink(for: label.kind, lane: lane).color
        HStack(spacing: 0) {
            if let glyph = Self.glyph(for: label.kind) {
                Image(systemName: glyph)
                    .font(.system(size: Metrics.Badge.iconFont, weight: isCurrent ? .heavy : .bold))
                    .frame(width: Metrics.Badge.iconCellWidth)
                Rectangle()
                    .fill(ink)
                    .frame(width: Metrics.Badge.borderWidth)
            }
            Text(title)
                .font(Metrics.Font.caption.weight(isCurrent || isDetached ? .bold : .medium))
                .padding(.horizontal, Metrics.Badge.padding)
        }
        .lineLimit(1)
        .foregroundStyle(ink)
        .frame(height: Metrics.Badge.height)
        .background(isDetached ? Palette.Status.conflict.tint.color : ink.opacity(Palette.Ink.laneFill), in: shape)
        .overlay(shape.strokeBorder(ink, lineWidth: Metrics.Badge.borderWidth))
        .help(help)
    }

    static func ink(for kind: RefLabel.Kind, lane: Int) -> ColorToken {
        kind == .detachedHead ? Palette.Status.conflict.ink : CommitGraphPalette.entries[CommitGraphPalette.index(lane)]
    }

    static func glyph(for kind: RefLabel.Kind) -> String? {
        switch kind {
        case .currentBranch: "checkmark"
        case .localBranch: "arrow.triangle.branch"
        case .remoteBranch: "cloud"
        case .tag: "tag"
        case .detachedHead: nil
        case .stash: "archivebox"
        case .more: nil
        }
    }

    private var title: String {
        label.others.isEmpty ? label.name : "\(label.name) +\(label.others.count)"
    }

    private var help: String {
        switch label.kind {
        case .currentBranch: "Current branch \(label.name)"
        case .localBranch: "Local branch \(label.name)"
        case .remoteBranch: "Remote-tracking branch \(label.name)"
        case .tag: label.others.isEmpty ? "Tag \(label.name)" : "Tags \(([label.name] + label.others).joined(separator: ", "))"
        case .detachedHead: "HEAD is detached at this commit"
        case .stash: "Stash \(label.name): changes put aside with git stash, based on the commit below it"
        case .more: "Also on this commit: \(label.others.joined(separator: ", "))"
        }
    }
}
