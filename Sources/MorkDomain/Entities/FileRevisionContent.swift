import Foundation

public enum FileRevisionContent: Equatable, Sendable {
    public static let textLimit = 2 * 1024 * 1024
    public static let binarySniffLength = 8_000

    case text(String, byteCount: Int)
    case binary(byteCount: Int)
    case tooLarge(byteCount: Int)

    public var byteCount: Int {
        switch self {
        case let .text(_, count), let .binary(count), let .tooLarge(count): count
        }
    }

    public static func isBinary(_ data: Data) -> Bool {
        data.prefix(binarySniffLength).contains(0)
    }

    public static func make(_ data: Data) -> FileRevisionContent {
        isBinary(data) ? .binary(byteCount: data.count) : .text(LosslessText.decode(data), byteCount: data.count)
    }
}
