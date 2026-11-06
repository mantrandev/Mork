import Foundation

public struct GitProgressLog: Equatable, Sendable {
    public static let limit = 200

    public private(set) var lines: [String] = []

    public init() {}

    public var latest: String? { lines.last }
    public var percent: Int? { lines.last.flatMap { Self.progress(in: $0)?.percent } }

    public mutating func append(_ line: String) {
        if let phase = Self.progress(in: line)?.phase, let last = lines.last, Self.progress(in: last)?.phase == phase {
            lines[lines.count - 1] = line
        } else {
            lines.append(line)
        }
        if lines.count > Self.limit {
            lines.removeFirst(lines.count - Self.limit)
        }
    }

    private static func progress(in line: String) -> (phase: Substring, percent: Int)? {
        guard let match = line.firstMatch(of: /\s*(\d{1,3})%/), let percent = Int(match.1) else { return nil }
        return (line[..<match.range.lowerBound], percent)
    }
}
