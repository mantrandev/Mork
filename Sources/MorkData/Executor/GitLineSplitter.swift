import Foundation

struct GitLineSplitter {
    private var pending: [UInt8] = []

    mutating func feed(_ data: Data) -> [String] {
        var lines: [String] = []
        for byte in data {
            if byte == UInt8(ascii: "\n") || byte == UInt8(ascii: "\r") {
                lines += take()
            } else {
                pending.append(byte)
            }
        }
        return lines
    }

    mutating func flush() -> [String] {
        take()
    }

    private mutating func take() -> [String] {
        defer { pending.removeAll(keepingCapacity: true) }
        return pending.isEmpty ? [] : [String(decoding: pending, as: UTF8.self)]
    }
}
