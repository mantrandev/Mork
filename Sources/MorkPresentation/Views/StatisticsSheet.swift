import Charts
import MorkDomain
import SwiftUI

struct StatisticsSheet: View {
    let session: StatisticsViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.Sheet.sectionSpacing) {
            DialogHeader(kind: .notice, glyph: "chart.bar", title: "Statistics for \(session.repositoryName)", message: "Counted from git log over all branches and tags. Mork only reads; nothing in the repository changes.")
            StatisticsContent(session: session)
            DialogButtonRow {
                DialogConfirmButton(title: "Done", identifier: "statistics.done") { dismiss() }
            }
        }
        .padding(Metrics.Sheet.padding)
        .frame(width: Metrics.Statistics.width, height: Metrics.Statistics.height)
        .dialogSurface()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("statistics.sheet")
    }
}

struct StatisticsContent: View {
    enum Tab: String, CaseIterable, Identifiable {
        case authors = "Authors"
        case activity = "Activity"
        case files = "Files"

        var id: String { rawValue }
    }

    let session: StatisticsViewModel
    @State private var tab = Tab.authors

    var body: some View {
        switch session.state {
        case .idle, .loading:
            ProgressView { Text("Reading git log…").font(Metrics.Font.body).foregroundStyle(Palette.Text.secondary.color) }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityIdentifier("statistics.loading")
        case let .failed(message):
            EmptyStateView("Statistics Failed", systemImage: "exclamationmark.triangle", message: message)
                .accessibilityIdentifier("statistics.failed")
        case let .loaded(statistics) where statistics.isEmpty:
            EmptyStateView("No Commits Yet", systemImage: "chart.bar", message: "Statistics count commits. Make the first commit, then open Statistics again.")
                .accessibilityIdentifier("statistics.empty")
        case let .loaded(statistics):
            VStack(alignment: .leading, spacing: Metrics.Sheet.rowSpacing) {
                StatisticsTotalsView(statistics: statistics)
                Picker("Section", selection: $tab) {
                    ForEach(Tab.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .accessibilityIdentifier("statistics.tab")
                switch tab {
                case .authors: StatisticsAuthorsView(authors: statistics.authors)
                case .activity: StatisticsActivityView(statistics: statistics)
                case .files: StatisticsFilesView(session: session, files: statistics.topFiles)
                }
            }
        }
    }
}

private struct StatisticsTotalsView: View {
    let statistics: RepositoryStatistics

    var body: some View {
        let totals = statistics.totals
        Grid(alignment: .leading, horizontalSpacing: Metrics.Spacing.xxl, verticalSpacing: Metrics.Spacing.xs) {
            GridRow {
                total("Commits", "\(totals.commits)", detail: "\(totals.merges) merges", identifier: "statistics.totals.commits")
                total("Authors", "\(totals.authors)", detail: "by name and email", identifier: "statistics.totals.authors")
                total("Branches", "\(totals.branches)", detail: "local", identifier: "statistics.totals.branches")
                total("Tags", "\(totals.tags)", detail: "", identifier: "statistics.totals.tags")
                total("First Commit", totals.firstCommit.map { $0.formatted(date: .abbreviated, time: .omitted) } ?? "—", detail: StatisticsText.age(days: statistics.ageInDays) + " ago", identifier: "statistics.totals.firstCommit")
            }
        }
        .padding(Metrics.Sheet.commandStripInset)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.Surface.well.color, in: RoundedRectangle(cornerRadius: Metrics.Radius.card, style: .continuous))
    }

    private func total(_ title: String, _ value: String, detail: String, identifier: String) -> some View {
        VStack(alignment: .leading, spacing: Metrics.Spacing.xxs) {
            Text(title.uppercased()).font(Metrics.Font.label).tracking(Metrics.Font.labelTracking).foregroundStyle(Palette.Text.secondary.color)
            Text(value).font(Metrics.Font.display.monospacedDigit()).foregroundStyle(Palette.Text.primary.color)
            Text(detail).font(Metrics.Font.caption).foregroundStyle(Palette.Text.secondary.color)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(identifier)
    }
}

private struct StatisticsAuthorsView: View {
    let authors: [AuthorStatistics]

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.Spacing.xs) {
            DialogNote(text: "git log --all --format=%aN %aE uses .mailmap, so one person with several emails can be merged there.")
            List(authors) { author in
                HStack(spacing: Metrics.Spacing.m) {
                    VStack(alignment: .leading, spacing: Metrics.Spacing.xxs) {
                        Text(author.name).font(Metrics.Font.title.weight(.medium)).foregroundStyle(Palette.Text.primary.color).lineLimit(1)
                        Text(author.email).font(Metrics.Font.caption).foregroundStyle(Palette.Text.secondary.color).lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Text(StatisticsText.commits(author.commits)).font(Metrics.Font.body.monospacedDigit()).foregroundStyle(Palette.Text.primary.color).frame(width: Metrics.Statistics.commitsColumn, alignment: .trailing)
                    Text("\(author.merges) merges").font(Metrics.Font.body.monospacedDigit()).foregroundStyle(Palette.Text.secondary.color).frame(width: Metrics.Statistics.mergesColumn, alignment: .trailing)
                    Text("\(author.firstDate.formatted(date: .abbreviated, time: .omitted)) – \(author.lastDate.formatted(date: .abbreviated, time: .omitted))")
                        .font(Metrics.Font.caption.monospacedDigit())
                        .foregroundStyle(Palette.Text.secondary.color)
                        .frame(width: Metrics.Statistics.datesColumn, alignment: .trailing)
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("statistics.author.\(author.name)")
            }
            .accessibilityIdentifier("statistics.authors")
        }
    }
}

private struct StatisticsActivityView: View {
    let statistics: RepositoryStatistics

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.Spacing.s) {
            Text("Commits per week, last \(statistics.weeks.count) weeks").font(Metrics.Font.title.weight(.semibold)).foregroundStyle(Palette.Text.primary.color)
            Chart(statistics.weeks) { week in
                BarMark(x: .value("Week", week.start, unit: .weekOfYear), y: .value("Commits", week.commits))
                    .foregroundStyle(Palette.Accent.fill.color)
                    .accessibilityLabel(StatisticsText.weekLabel(week))
                    .accessibilityValue(StatisticsText.weekValue(week))
            }
            .chartYAxisLabel("Commits")
            .frame(height: Metrics.Statistics.chartHeight)
            .accessibilityIdentifier("statistics.weeklyChart")
            Text("Commits by weekday and hour (author's local time)").font(Metrics.Font.title.weight(.semibold)).foregroundStyle(Palette.Text.primary.color)
            ActivityHeatmapView(heatmap: statistics.heatmap)
        }
    }
}

private struct ActivityHeatmapView: View {
    let heatmap: ActivityHeatmap

    var body: some View {
        let maximum = max(heatmap.maximum, 1)
        Grid(horizontalSpacing: Metrics.Spacing.xxs, verticalSpacing: Metrics.Spacing.xxs) {
            GridRow {
                Text("")
                ForEach(0..<ActivityHeatmap.hours, id: \.self) { hour in
                    Text(hour % Metrics.Statistics.heatmapHourStep == 0 ? "\(hour)" : "").font(.system(size: Metrics.Statistics.heatmapAxisFont).monospacedDigit()).foregroundStyle(Palette.Text.secondary.color)
                }
            }
            ForEach(0..<ActivityHeatmap.weekdays, id: \.self) { weekday in
                GridRow {
                    Text(String(ActivityHeatmap.weekdayNames[weekday].prefix(3))).font(Metrics.Font.caption).foregroundStyle(Palette.Text.secondary.color)
                    ForEach(0..<ActivityHeatmap.hours, id: \.self) { hour in
                        let count = heatmap.count(weekday: weekday, hour: hour)
                        RoundedRectangle(cornerRadius: Metrics.Radius.badge)
                            .fill(count == 0 ? Palette.Surface.rowAlt.color : Palette.Accent.fill.color.opacity(Metrics.Statistics.heatmapMinimumOpacity + (1 - Metrics.Statistics.heatmapMinimumOpacity) * Double(count) / Double(maximum)))
                            .frame(width: Metrics.Statistics.heatmapCellWidth, height: Metrics.Statistics.heatmapCellHeight)
                            .help(StatisticsText.heatmapLabel(weekday: weekday, hour: hour, count: count))
                            .accessibilityLabel(StatisticsText.heatmapLabel(weekday: weekday, hour: hour, count: count))
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("statistics.heatmap")
    }
}

private struct StatisticsFilesView: View {
    let session: StatisticsViewModel
    let files: [FileChangeCount]

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.Spacing.s) {
            HStack {
                Text("Most changed files in the last").font(Metrics.Font.title.weight(.semibold)).foregroundStyle(Palette.Text.primary.color)
                Picker("Commits", selection: Binding(get: { session.fileCommitLimit }, set: { limit in Task { await session.setFileCommitLimit(limit) } })) {
                    ForEach(StatisticsViewModel.fileCommitLimits, id: \.self) { Text("\($0) commits").tag($0) }
                }
                .labelsHidden()
                .fixedSize()
                .accessibilityIdentifier("statistics.fileLimit")
                Spacer()
            }
            DialogNote(text: "git log -n \(session.fileCommitLimit) --name-only counts each commit that touched a file. Merge commits list no files.")
            let maximum = max(files.first?.changes ?? 1, 1)
            List(files) { file in
                HStack {
                    Text(file.path).font(Metrics.Font.title).foregroundStyle(Palette.Text.primary.color).lineLimit(1).truncationMode(.middle)
                    Spacer()
                    Capsule().fill(Palette.Accent.fill.color.opacity(Metrics.Statistics.fileBarOpacity)).frame(width: Metrics.Statistics.fileBarWidth * CGFloat(file.changes) / CGFloat(maximum), height: Metrics.Statistics.fileBarHeight)
                    Text(StatisticsText.commits(file.changes)).font(Metrics.Font.body.monospacedDigit()).foregroundStyle(Palette.Text.primary.color).frame(width: Metrics.Statistics.fileCountColumn, alignment: .trailing)
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("statistics.file.\(file.path)")
            }
            .accessibilityIdentifier("statistics.files")
        }
    }
}
