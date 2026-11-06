import CoreGraphics

@MainActor
enum RepositoryPaneLayout {
    static func bottomPanelMaximumHeight(detailHeight: CGFloat) -> CGFloat {
        guard detailHeight > 0 else { return Metrics.Panel.maximumHeight }
        let byShare = detailHeight * Metrics.Panel.maximumShare
        let byContent = detailHeight - Metrics.Toolbar.bandHeight - Metrics.Panel.minimumContentHeight
        return max(Metrics.Panel.minimumHeight, min(byShare, byContent))
    }

    static func bottomPanelHeight(saved: CGFloat?, detailHeight: CGFloat) -> CGFloat {
        let fallback = CGFloat(AppViewModel.defaultBottomPanelHeight)
        let preferred = saved ?? (detailHeight > 0 ? min(fallback, detailHeight * Metrics.Panel.defaultShare) : fallback)
        return min(max(preferred, Metrics.Panel.minimumHeight), bottomPanelMaximumHeight(detailHeight: detailHeight))
    }

    static func historyListHeight(saved: CGFloat?, browserHeight: CGFloat) -> CGFloat {
        guard browserHeight > 0 else { return saved ?? Metrics.HistoryPane.listIdealHeight }
        let preferred = saved ?? browserHeight * Metrics.HistoryPane.listShare
        let maximum = max(Metrics.HistoryPane.listMinimumHeight, browserHeight - Metrics.HistoryPane.detailsFrameMinimumHeight)
        return min(max(preferred, Metrics.HistoryPane.listMinimumHeight), maximum)
    }

    static func conflictBlocksHeight(saved: CGFloat?, firstCardHeight: CGFloat?, cardsHeight: CGFloat?, available: CGFloat) -> CGFloat {
        guard available > 0 else { return saved ?? Metrics.Conflict.blocksHeight }
        let share = available * Metrics.Conflict.blocksShare
        let preferred = saved ?? max(min(cardsHeight ?? share, share), firstCardHeight ?? 0)
        let wanted = min(preferred, cardsHeight ?? preferred)
        let chrome = Metrics.Line.hairline * 2 + Metrics.Panel.header + Metrics.Conflict.footerHeight
        return max(0, min(wanted, available - chrome - Metrics.Conflict.resultMinimumHeight))
    }
}
