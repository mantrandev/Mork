import Foundation

public struct BenchmarkCommand: Hashable, Sendable {
    public let arguments: [String]
    public let input: String?

    public init(arguments: [String], input: String? = nil) {
        self.arguments = arguments
        self.input = input
    }

    public var commandLine: String {
        (["git"] + arguments.map(ShellWords.quote)).joined(separator: " ")
    }
}

public struct PerformanceTraceEntry: Equatable, Sendable {
    public let label: String
    public let seconds: Double

    public init(label: String, seconds: Double) {
        self.label = label
        self.seconds = seconds
    }

    public static func parse(_ trace: String) -> [PerformanceTraceEntry] {
        var totals: [String: Double] = [:]
        var order: [String] = []
        for line in trace.split(whereSeparator: \.isNewline) {
            guard let marker = line.range(of: "performance: ") else { continue }
            let rest = line[marker.upperBound...]
            guard let unit = rest.range(of: " s:"), let seconds = Double(rest[..<unit.lowerBound]) else { continue }
            let label = rest[unit.upperBound...].trimmingCharacters(in: .whitespaces)
            guard !label.isEmpty, !label.hasPrefix("git command:") else { continue }
            if totals[label] == nil { order.append(label) }
            totals[label, default: 0] += seconds
        }
        return order.map { PerformanceTraceEntry(label: $0, seconds: totals[$0] ?? 0) }.sorted { $0.seconds > $1.seconds }
    }
}

public struct BenchmarkResult: Identifiable, Equatable, Sendable {
    public let command: BenchmarkCommand
    public let samples: [Double]
    public let trace: [PerformanceTraceEntry]

    public init(command: BenchmarkCommand, samples: [Double], trace: [PerformanceTraceEntry]) {
        self.command = command
        self.samples = samples
        self.trace = trace
    }

    public var id: String { command.commandLine + (command.input ?? "") }
    public var median: Double { Self.percentile(samples, 0.5) }
    public var p95: Double { Self.percentile(samples, 0.95) }
    public var fastest: Double { samples.min() ?? 0 }
    public var slowest: Double { samples.max() ?? 0 }

    public static func percentile(_ samples: [Double], _ fraction: Double) -> Double {
        guard !samples.isEmpty else { return 0 }
        let sorted = samples.sorted()
        let rank = Int((fraction * Double(sorted.count)).rounded(.up)) - 1
        return sorted[min(max(rank, 0), sorted.count - 1)]
    }
}

public struct BenchmarkReport: Equatable, Sendable {
    public let runs: Int
    public let results: [BenchmarkResult]

    public init(runs: Int, results: [BenchmarkResult]) {
        self.runs = runs
        self.results = results
    }

    public var medianTotal: Double { results.map(\.median).reduce(0, +) }
}

public struct BenchmarkProgress: Equatable, Sendable {
    public let completed: Int
    public let total: Int
    public let command: String

    public init(completed: Int, total: Int, command: String) {
        self.completed = completed
        self.total = total
        self.command = command
    }

    public var fraction: Double { total == 0 ? 0 : Double(completed) / Double(total) }
}
