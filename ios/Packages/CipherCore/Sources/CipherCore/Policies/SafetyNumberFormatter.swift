import Foundation

public enum SafetyNumberError: Error, LocalizedError, Hashable, Sendable {
    case emptyInput
    case invalidHex

    public var errorDescription: String? {
        switch self {
        case .emptyInput:
            CoreStrings.localized("error.safetyNumber.empty", default: "There is no fingerprint to display yet.")
        case .invalidHex:
            CoreStrings.localized("error.safetyNumber.invalidHex", default: "The fingerprint could not be read.")
        }
    }
}

/// A fingerprint rendered as decimal blocks people can read aloud to each other.
public struct SafetyNumber: Hashable, Sendable {
    /// Five-digit, zero-padded blocks.
    public var blocks: [String]

    public init(blocks: [String]) {
        self.blocks = blocks
    }

    public var digits: String {
        blocks.joined()
    }

    /// Blocks separated by spaces, for a monospaced label.
    public var displayString: String {
        blocks.joined(separator: " ")
    }

    /// Rows of `perRow` blocks, for a grid layout.
    public func rows(of perRow: Int = 4) -> [[String]] {
        let width = max(1, perRow)
        return stride(from: 0, to: blocks.count, by: width).map { start in
            Array(blocks[start..<min(start + width, blocks.count)])
        }
    }

    /// Digits spaced out so VoiceOver reads "one two three" instead of "one hundred twenty-three",
    /// with a pause between blocks.
    public var accessibilityLabel: String {
        blocks.map { $0.map(String.init).joined(separator: " ") }.joined(separator: ", ")
    }
}

/// Converts a hex fingerprint into 5-digit blocks. Every two bytes become one block (0…65535 fits in
/// five digits), so the mapping is lossless: two people whose numbers match have matching keys, with
/// no weaker guarantee than comparing the hex itself. Hex is hard to read aloud; digits are not.
public struct SafetyNumberFormatter: Sendable {
    public init() {}

    public func format(_ fingerprint: SafetyFingerprint) throws(SafetyNumberError) -> SafetyNumber {
        try format(hex: fingerprint.hex)
    }

    /// Accepts upper or lower case and ignores spaces and colons ("ab:cd ef") so pasted output from
    /// other tools still formats. Any other character is an error rather than a silently skipped digit.
    public func format(hex: String) throws(SafetyNumberError) -> SafetyNumber {
        let bytes = try Self.bytes(fromHex: hex)
        guard !bytes.isEmpty else { throw SafetyNumberError.emptyInput }
        var blocks: [String] = []
        blocks.reserveCapacity((bytes.count + 1) / 2)
        var index = 0
        while index < bytes.count {
            let high = Int(bytes[index])
            let low = index + 1 < bytes.count ? Int(bytes[index + 1]) : 0
            let value = high << 8 | low
            blocks.append(Self.padded(value))
            index += 2
        }
        return SafetyNumber(blocks: blocks)
    }

    private static func padded(_ value: Int) -> String {
        let raw = String(value)
        return String(repeating: "0", count: max(0, 5 - raw.count)) + raw
    }

    private static func bytes(fromHex hex: String) throws(SafetyNumberError) -> [UInt8] {
        let cleaned = hex.filter { !$0.isWhitespace && $0 != ":" }
        guard !cleaned.isEmpty else { throw SafetyNumberError.emptyInput }
        guard cleaned.count.isMultiple(of: 2) else { throw SafetyNumberError.invalidHex }
        var bytes: [UInt8] = []
        bytes.reserveCapacity(cleaned.count / 2)
        var iterator = cleaned.makeIterator()
        while let first = iterator.next(), let second = iterator.next() {
            guard let high = first.hexDigitValue, let low = second.hexDigitValue else {
                throw SafetyNumberError.invalidHex
            }
            bytes.append(UInt8(high << 4 | low))
        }
        return bytes
    }
}
