import Foundation

public enum LosslessText {
    private static let escapeBase: UInt32 = 0x10FF00
    private static let escapeRange: ClosedRange<UInt32> = 0x10FF80...0x10FFFF
    private static let escapeLead: UInt8 = 0xF4

    public static func decode(_ data: Data) -> String {
        let text = String(decoding: data, as: UTF8.self)
        if !contains(escapeLead, in: data), sameBytes(text, data) { return text }
        return slowDecode([UInt8](data))
    }

    public static func encode(_ text: String) -> Data {
        guard mayContainEscapes(text) else { return Data(text.utf8) }
        var bytes: [UInt8] = []
        bytes.reserveCapacity(text.utf8.count)
        for scalar in text.unicodeScalars {
            if escapeRange.contains(scalar.value) {
                bytes.append(UInt8(scalar.value - escapeBase))
            } else {
                bytes.append(contentsOf: String(scalar).utf8)
            }
        }
        return Data(bytes)
    }

    public static func displayable(_ text: String) -> String {
        guard mayContainEscapes(text) else { return text }
        var scalars = String.UnicodeScalarView()
        for scalar in text.unicodeScalars {
            scalars.append(escapeRange.contains(scalar.value) ? "\u{FFFD}" : scalar)
        }
        return String(scalars)
    }

    private static func mayContainEscapes(_ text: String) -> Bool {
        var copy = text
        return copy.withUTF8 { buffer in
            guard let base = buffer.baseAddress else { return false }
            return memchr(base, Int32(escapeLead), buffer.count) != nil
        }
    }

    private static func contains(_ byte: UInt8, in data: Data) -> Bool {
        data.withUnsafeBytes { buffer in
            guard let base = buffer.baseAddress else { return false }
            return memchr(base, Int32(byte), buffer.count) != nil
        }
    }

    private static func sameBytes(_ text: String, _ data: Data) -> Bool {
        var copy = text
        return copy.withUTF8 { utf8 in
            guard utf8.count == data.count else { return false }
            return data.withUnsafeBytes { raw in
                guard let left = utf8.baseAddress, let right = raw.baseAddress else { return true }
                return memcmp(left, right, utf8.count) == 0
            }
        }
    }

    private static func slowDecode(_ bytes: [UInt8]) -> String {
        var scalars = String.UnicodeScalarView()
        var index = 0
        while index < bytes.count {
            if let (scalar, length) = scalar(at: index, in: bytes) {
                scalars.append(scalar)
                index += length
            } else {
                scalars.append(Unicode.Scalar(escapeBase + UInt32(bytes[index]))!)
                index += 1
            }
        }
        return String(scalars)
    }

    private static func scalar(at index: Int, in bytes: [UInt8]) -> (Unicode.Scalar, Int)? {
        let lead = bytes[index]
        if lead < 0x80 { return (Unicode.Scalar(lead), 1) }
        let length: Int
        var value: UInt32
        let minimum: UInt32
        switch lead {
        case 0xC0...0xDF: (length, value, minimum) = (2, UInt32(lead & 0x1F), 0x80)
        case 0xE0...0xEF: (length, value, minimum) = (3, UInt32(lead & 0x0F), 0x800)
        case 0xF0...0xF7: (length, value, minimum) = (4, UInt32(lead & 0x07), 0x10000)
        default: return nil
        }
        guard index + length <= bytes.count else { return nil }
        for offset in 1..<length {
            let byte = bytes[index + offset]
            guard byte & 0xC0 == 0x80 else { return nil }
            value = value << 6 | UInt32(byte & 0x3F)
        }
        guard value >= minimum, !escapeRange.contains(value), let scalar = Unicode.Scalar(value) else { return nil }
        return (scalar, length)
    }
}
