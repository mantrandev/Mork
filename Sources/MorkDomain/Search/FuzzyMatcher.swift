import Foundation

public struct FuzzyMatch: Equatable, Sendable {
    public let score: Int
    public let ranges: [Range<Int>]

    public init(score: Int, ranges: [Range<Int>]) {
        self.score = score
        self.ranges = ranges
    }
}

public struct FuzzyRanked: Equatable, Sendable {
    public let index: Int
    public let match: FuzzyMatch

    public init(index: Int, match: FuzzyMatch) {
        self.index = index
        self.match = match
    }
}

public enum FuzzyMatcher {
    static let matchScore = 16
    static let firstCharacterBonus = 10
    static let separatorBonus = 8
    static let camelCaseBonus = 7
    static let consecutiveBonus = 6
    static let exactCaseBonus = 1
    static let gapStartPenalty = 3
    static let gapExtensionPenalty = 1

    public static func match(_ query: String, in candidate: String) -> FuzzyMatch? {
        Query(query).match(candidate)
    }

    public static func rank(_ candidates: [String], query: String, limit: Int) -> [FuzzyRanked] {
        guard limit > 0 else { return [] }
        let prepared = Query(query)
        guard !prepared.isEmpty else {
            return candidates.indices.prefix(limit).map { FuzzyRanked(index: $0, match: FuzzyMatch(score: 0, ranges: [])) }
        }
        var best: [(ranked: FuzzyRanked, length: Int)] = []
        best.reserveCapacity(limit + 1)
        for (index, candidate) in candidates.enumerated() {
            guard let match = prepared.match(candidate) else { continue }
            let length = candidate.utf8.count
            if best.count == limit, let worst = best.last, !precedes(match.score, length, than: worst.ranked.match.score, worst.length) {
                continue
            }
            let entry = (ranked: FuzzyRanked(index: index, match: match), length: length)
            let position = best.firstIndex { precedes(match.score, length, than: $0.ranked.match.score, $0.length) } ?? best.count
            best.insert(entry, at: position)
            if best.count > limit { best.removeLast() }
        }
        return best.map(\.ranked)
    }

    private static func precedes(_ score: Int, _ length: Int, than otherScore: Int, _ otherLength: Int) -> Bool {
        score != otherScore ? score > otherScore : length < otherLength
    }
}

private struct Query {
    let original: [Unicode.Scalar]
    let folded: [Unicode.Scalar]

    let asciiOriginal: [UInt8]?
    let asciiFolded: [UInt8]?

    init(_ text: String) {
        original = text.unicodeScalars.filter { !$0.properties.isWhitespace }
        folded = original.map(Self.fold)
        if original.allSatisfy(\.isASCII) {
            asciiOriginal = original.map { UInt8($0.value) }
            asciiFolded = folded.map { UInt8($0.value) }
        } else {
            asciiOriginal = nil
            asciiFolded = nil
        }
    }

    var isEmpty: Bool { folded.isEmpty }

    func match(_ candidate: String) -> FuzzyMatch? {
        guard !folded.isEmpty else { return FuzzyMatch(score: 0, ranges: []) }
        if let asciiOriginal, let asciiFolded {
            var candidate = candidate
            let outcome = candidate.withUTF8 { ASCIIMatcher(original: asciiOriginal, folded: asciiFolded, bytes: $0).match() }
            if case let .finished(match) = outcome { return match }
        }
        let scalars = Array(candidate.unicodeScalars)
        guard scalars.count >= folded.count, let end = forwardEnd(in: scalars) else { return nil }
        let start = backwardStart(in: scalars, from: end)
        let positions = greedyPositions(in: scalars, from: start)
        return FuzzyMatch(score: score(positions, in: scalars), ranges: Self.ranges(of: positions))
    }

    private func forwardEnd(in scalars: [Unicode.Scalar]) -> Int? {
        var queryIndex = 0
        for index in scalars.indices where Self.fold(scalars[index]) == folded[queryIndex] {
            queryIndex += 1
            if queryIndex == folded.count { return index }
        }
        return nil
    }

    private func backwardStart(in scalars: [Unicode.Scalar], from end: Int) -> Int {
        var queryIndex = folded.count - 1
        var index = end
        while index >= 0 {
            if Self.fold(scalars[index]) == folded[queryIndex] {
                if queryIndex == 0 { return index }
                queryIndex -= 1
            }
            index -= 1
        }
        return 0
    }

    private func greedyPositions(in scalars: [Unicode.Scalar], from start: Int) -> [Int] {
        var positions: [Int] = []
        positions.reserveCapacity(folded.count)
        var index = start
        while positions.count < folded.count {
            if Self.fold(scalars[index]) == folded[positions.count] { positions.append(index) }
            index += 1
        }
        return positions
    }

    private func score(_ positions: [Int], in scalars: [Unicode.Scalar]) -> Int {
        var total = 0
        var previous: Int?
        for (queryIndex, position) in positions.enumerated() {
            total += FuzzyMatcher.matchScore + Self.boundaryBonus(at: position, in: scalars)
            if scalars[position] == original[queryIndex] { total += FuzzyMatcher.exactCaseBonus }
            if let previous {
                let gap = position - previous - 1
                if gap == 0 {
                    total += FuzzyMatcher.consecutiveBonus
                } else {
                    total -= FuzzyMatcher.gapStartPenalty + (gap - 1) * FuzzyMatcher.gapExtensionPenalty
                }
            }
            previous = position
        }
        return total
    }

    private static func boundaryBonus(at position: Int, in scalars: [Unicode.Scalar]) -> Int {
        guard position > 0 else { return FuzzyMatcher.firstCharacterBonus }
        let previous = scalars[position - 1]
        if isSeparator(previous) { return FuzzyMatcher.separatorBonus }
        if previous.properties.isLowercase && scalars[position].properties.isUppercase { return FuzzyMatcher.camelCaseBonus }
        return 0
    }

    private static func isSeparator(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar {
        case "/", "-", "_", ".", " ", ":", "\\": true
        default: scalar.properties.isWhitespace
        }
    }

    private static func ranges(of positions: [Int]) -> [Range<Int>] {
        var ranges: [Range<Int>] = []
        for position in positions {
            if let last = ranges.last, last.upperBound == position {
                ranges[ranges.count - 1] = last.lowerBound..<(position + 1)
            } else {
                ranges.append(position..<(position + 1))
            }
        }
        return ranges
    }

    static func fold(_ scalar: Unicode.Scalar) -> Unicode.Scalar {
        let value = scalar.value
        if value < 0x80 {
            return value >= 0x41 && value <= 0x5A ? Unicode.Scalar(UInt8(value + 0x20)) : scalar
        }
        guard scalar.properties.changesWhenLowercased else { return scalar }
        let lowered = scalar.properties.lowercaseMapping.unicodeScalars
        return lowered.count == 1 ? lowered[lowered.startIndex] : scalar
    }
}

private enum ASCIIOutcome {
    case finished(FuzzyMatch?)
    case notASCII
}

private struct ASCIIMatcher {
    let original: [UInt8]
    let folded: [UInt8]
    let bytes: UnsafeBufferPointer<UInt8>

    func match() -> ASCIIOutcome {
        let count = bytes.count
        let queryCount = folded.count
        var queryIndex = 0
        var end = -1
        var index = 0
        while index < count {
            let byte = bytes[index]
            if byte >= 0x80 { return .notASCII }
            if queryIndex < queryCount && Self.fold(byte) == folded[queryIndex] {
                queryIndex += 1
                if queryIndex == queryCount {
                    end = index
                    break
                }
            }
            index += 1
        }
        guard end >= 0 else { return .finished(nil) }
        var start = end
        queryIndex = queryCount - 1
        while start >= 0 {
            if Self.fold(bytes[start]) == folded[queryIndex] {
                if queryIndex == 0 { break }
                queryIndex -= 1
            }
            start -= 1
        }
        var total = 0
        var ranges: [Range<Int>] = []
        var previous = -1
        queryIndex = 0
        index = start
        while queryIndex < queryCount {
            let byte = bytes[index]
            if Self.fold(byte) == folded[queryIndex] {
                total += FuzzyMatcher.matchScore + bonus(at: index)
                if byte == original[queryIndex] { total += FuzzyMatcher.exactCaseBonus }
                if previous >= 0 {
                    let gap = index - previous - 1
                    if gap == 0 {
                        total += FuzzyMatcher.consecutiveBonus
                    } else {
                        total -= FuzzyMatcher.gapStartPenalty + (gap - 1) * FuzzyMatcher.gapExtensionPenalty
                    }
                }
                if previous >= 0 && previous == index - 1 {
                    ranges[ranges.count - 1] = ranges[ranges.count - 1].lowerBound..<(index + 1)
                } else {
                    ranges.append(index..<(index + 1))
                }
                previous = index
                queryIndex += 1
            }
            index += 1
        }
        return .finished(FuzzyMatch(score: total, ranges: ranges))
    }

    private func bonus(at index: Int) -> Int {
        guard index > 0 else { return FuzzyMatcher.firstCharacterBonus }
        let previous = bytes[index - 1]
        switch previous {
        case 0x2F, 0x2D, 0x5F, 0x2E, 0x20, 0x3A, 0x5C, 0x09: return FuzzyMatcher.separatorBonus
        default: break
        }
        let current = bytes[index]
        if previous >= 0x61 && previous <= 0x7A && current >= 0x41 && current <= 0x5A { return FuzzyMatcher.camelCaseBonus }
        return 0
    }

    private static func fold(_ byte: UInt8) -> UInt8 {
        byte >= 0x41 && byte <= 0x5A ? byte + 0x20 : byte
    }
}
