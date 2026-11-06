import Foundation

public struct IgnoreFileDocument: Equatable, Sendable {
    public enum LineEnding: String, Sendable {
        case lf = "\n"
        case crlf = "\r\n"
    }

    public let exists: Bool
    public let lineEnding: LineEnding
    public let text: String

    public init(contents: String?) {
        exists = contents != nil
        let contents = contents ?? ""
        let crlfCount = contents.components(separatedBy: LineEnding.crlf.rawValue).count - 1
        let newlineCount = contents.components(separatedBy: LineEnding.lf.rawValue).count - 1
        lineEnding = crlfCount * 2 > newlineCount ? .crlf : .lf
        text = Self.unixLines(contents)
    }

    public func serialized(_ edited: String) -> String {
        let unix = Self.unixLines(edited)
        return lineEnding == .lf ? unix : unix.replacingOccurrences(of: LineEnding.lf.rawValue, with: LineEnding.crlf.rawValue)
    }

    public func hasChanges(_ edited: String) -> Bool {
        !exists || Self.unixLines(edited) != text
    }

    private static func unixLines(_ text: String) -> String {
        text.replacingOccurrences(of: LineEnding.crlf.rawValue, with: LineEnding.lf.rawValue)
    }
}
