import MorkDomain
import SwiftUI

struct BenchmarkSheet: View {
    @Bindable var session: BenchmarkViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.Sheet.sectionSpacing) {
            DialogHeader(kind: .options, glyph: "stopwatch", title: "Performance Benchmark for \(session.repositoryName)")
            controls
            content
            DialogButtonRow {
                DialogConfirmButton(title: "Done", identifier: "benchmark.done") {
                    session.cancel()
                    dismiss()
                }
            }
        }
        .padding(Metrics.Sheet.padding)
        .frame(width: Metrics.Sheet.largeWidth, height: Metrics.Sheet.largeHeight)
        .dialogSurface()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("benchmark.sheet")
        .onDisappear { session.cancel() }
    }

    private var controls: some View {
        HStack(spacing: Metrics.Spacing.s) {
            Text("Runs per command")
                .font(Metrics.Font.title)
                .foregroundStyle(Palette.Text.secondary.color)
            Picker("Runs per command", selection: $session.runs) {
                ForEach(BenchmarkViewModel.runChoices, id: \.self) { Text("\($0) runs").tag($0) }
            }
            .labelsHidden()
            .fixedSize()
            .disabled(session.isRunning)
            .accessibilityIdentifier("benchmark.runs")
            if session.isRunning {
                Button("Cancel") { session.cancel() }
                    .buttonStyle(.morkSecondary)
                    .accessibilityIdentifier("benchmark.cancel")
            } else {
                Button(session.report == nil ? "Run Benchmark" : "Run Again") { Task { await session.start() } }
                    .buttonStyle(.morkSecondary)
                    .accessibilityIdentifier("benchmark.run")
            }
            Spacer()
            if let report = session.report {
                Text("\(report.results.count) commands, medians add up to \(BenchmarkViewModel.milliseconds(report.medianTotal))")
                    .font(Metrics.Font.caption.monospacedDigit())
                    .foregroundStyle(Palette.Text.secondary.color)
                    .accessibilityIdentifier("benchmark.summary")
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch session.state {
        case .idle:
            EmptyStateView("Ready", systemImage: "stopwatch", message: "Choose how many runs per command, then Run Benchmark. Mork first records the commands of one refresh, then times each of them.")
                .accessibilityIdentifier("benchmark.idle")
        case let .running(progress):
            VStack(alignment: .leading, spacing: Metrics.Spacing.s) {
                DialogProgressBar(fraction: progress.fraction)
                    .accessibilityIdentifier("benchmark.progress")
                if progress.command.isEmpty {
                    DialogNote(text: "Recording the commands of one refresh…")
                } else {
                    CommandStrip(command: progress.command, note: "running")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        case let .failed(message):
            EmptyStateView("Benchmark Failed", systemImage: "exclamationmark.triangle", message: message)
                .accessibilityIdentifier("benchmark.failed")
        case .cancelled:
            EmptyStateView("Cancelled", systemImage: "stop.circle", message: "Run the benchmark again to get numbers.")
                .accessibilityIdentifier("benchmark.cancelled")
        case let .finished(report):
            BenchmarkResults(session: session, report: report)
        }
    }
}

private struct BenchmarkResults: View {
    @Bindable var session: BenchmarkViewModel
    let report: BenchmarkReport

    var body: some View {
        VSplitView {
            Table(report.results, selection: $session.selection) {
                TableColumn("Command") { result in
                    Text(result.command.commandLine)
                        .font(Metrics.Font.monoCaption)
                        .foregroundStyle(Palette.Text.primary.color)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .help(result.command.commandLine)
                }
                TableColumn("Median") { Text(BenchmarkViewModel.milliseconds($0.median)).font(Metrics.Font.body.monospacedDigit()).foregroundStyle(Palette.Text.primary.color) }
                    .width(Metrics.Benchmark.numberColumn)
                TableColumn("p95") { Text(BenchmarkViewModel.milliseconds($0.p95)).font(Metrics.Font.body.monospacedDigit()).foregroundStyle(Palette.Text.primary.color) }
                    .width(Metrics.Benchmark.numberColumn)
                TableColumn("Fastest") { Text(BenchmarkViewModel.milliseconds($0.fastest)).font(Metrics.Font.body.monospacedDigit()).foregroundStyle(Palette.Text.secondary.color) }
                    .width(Metrics.Benchmark.numberColumn)
                TableColumn("Slowest") { Text(BenchmarkViewModel.milliseconds($0.slowest)).font(Metrics.Font.body.monospacedDigit()).foregroundStyle(Palette.Text.secondary.color) }
                    .width(Metrics.Benchmark.numberColumn)
            }
            .frame(minHeight: Metrics.Panel.minimumHeight)
            .accessibilityIdentifier("benchmark.table")
            BenchmarkTrace(result: session.selectedResult)
                .frame(minHeight: Metrics.Panel.minimumHeight)
        }
    }
}

private struct BenchmarkTrace: View {
    let result: BenchmarkResult?

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.Spacing.xs) {
            Text("GIT_TRACE_PERFORMANCE")
                .font(Metrics.Font.label)
                .tracking(Metrics.Font.labelTracking)
                .foregroundStyle(Palette.Text.secondary.color)
                .padding(.top, Metrics.Spacing.s)
            Text("With GIT_TRACE_PERFORMANCE=<file> set, git writes how long each internal step took (reading the index, refreshing it, walking commits). One extra run of the selected command:")
                .font(Metrics.Font.body)
                .foregroundStyle(Palette.Text.secondary.color)
                .fixedSize(horizontal: false, vertical: true)
            if let result, !result.trace.isEmpty {
                List(result.trace, id: \.label) { entry in
                    HStack {
                        Text(entry.label).font(Metrics.Font.monoCaption).foregroundStyle(Palette.Text.primary.color).lineLimit(1).truncationMode(.middle)
                        Spacer()
                        Text(BenchmarkViewModel.milliseconds(entry.seconds * 1_000)).font(Metrics.Font.caption.monospacedDigit()).foregroundStyle(Palette.Text.secondary.color)
                    }
                    .frame(height: Metrics.Row.list)
                }
                .listStyle(.bordered)
                .accessibilityIdentifier("benchmark.trace")
            } else {
                Text(result == nil ? "Select a command above." : "git reported no internal steps for this command.")
                    .font(Metrics.Font.caption)
                    .foregroundStyle(Palette.Text.secondary.color)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityIdentifier("benchmark.noTrace")
            }
        }
    }
}
