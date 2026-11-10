import Foundation

public struct DiffOptions: Hashable, Sendable, DiffOptionsProviding {
    public static let defaultContextLines = 3
    public static let entireFileContextLines = 1_000_000
    public static let standard = DiffOptions()

    public let contextLines: Int
    public let ignoresWhitespace: Bool

    public init(contextLines: Int = DiffOptions.defaultContextLines, ignoresWhitespace: Bool = false) {
        self.contextLines = contextLines
        self.ignoresWhitespace = ignoresWhitespace
    }

    public var arguments: [String] {
        Self.context(contextLines) + (ignoresWhitespace ? ["-w"] : [])
    }

    public var workingCopyArguments: [String] {
        Self.context(max(contextLines, 1))
    }

    public func diffOptions() -> DiffOptions {
        self
    }

    private static func context(_ lines: Int) -> [String] {
        lines == defaultContextLines ? [] : ["-U\(lines)"]
    }
}
