import Foundation

struct ConflictLineStarts: Equatable {
    private static let newline = UInt16(UInt8(ascii: "\n"))

    private(set) var starts: [Int]

    init(_ string: NSString) {
        starts = [0] + Self.lineStarts(in: string, range: NSRange(location: 0, length: string.length))
    }

    var count: Int { starts.count }

    func line(containing offset: Int) -> Int {
        max(upperBound(offset) - 1, 0)
    }

    mutating func edited(_ range: NSRange, changeInLength delta: Int, in string: NSString) {
        let lower = upperBound(range.location)
        let upper = upperBound(range.location + range.length - delta)
        let inserted = Self.lineStarts(in: string, range: range)
        starts.replaceSubrange(lower..<upper, with: inserted)
        guard delta != 0 else { return }
        for index in (lower + inserted.count)..<starts.count {
            starts[index] += delta
        }
    }

    private func upperBound(_ offset: Int) -> Int {
        var low = 0
        var high = starts.count
        while low < high {
            let middle = (low + high) / 2
            if starts[middle] <= offset {
                low = middle + 1
            } else {
                high = middle
            }
        }
        return low
    }

    private static func lineStarts(in string: NSString, range: NSRange) -> [Int] {
        guard range.length > 0 else { return [] }
        var buffer = [unichar](repeating: 0, count: range.length)
        string.getCharacters(&buffer, range: range)
        var starts: [Int] = []
        for (offset, unit) in buffer.enumerated() where unit == newline {
            starts.append(range.location + offset + 1)
        }
        return starts
    }
}
