import Foundation

public enum PINError: Error, LocalizedError, Hashable, Sendable {
    case invalidLength
    case notNumeric
    case tooPredictable
    case decoyMatchesReal

    public var errorDescription: String? {
        switch self {
        case .invalidLength:
            CoreStrings.localized("error.pin.invalidLength", default: "Use between 4 and 8 digits.")
        case .notNumeric:
            CoreStrings.localized("error.pin.notNumeric", default: "A PIN can only contain digits.")
        case .tooPredictable:
            CoreStrings.localized("error.pin.tooPredictable", default: "That PIN is too easy to guess.")
        case .decoyMatchesReal:
            CoreStrings.localized("error.pin.decoyMatchesReal", default: "The decoy PIN must differ from your real PIN.")
        }
    }
}

/// What a PIN must look like before it is accepted. Kept in the domain so the setup screen and the
/// verifier implementation enforce the same rules.
public enum PINRules {
    public static let minimumLength = 4
    public static let maximumLength = 8

    public static func validate(_ pin: String) throws(PINError) {
        guard (minimumLength...maximumLength).contains(pin.count) else { throw PINError.invalidLength }
        guard pin.allSatisfy({ $0.isASCII && $0.isNumber }) else { throw PINError.notNumeric }
        guard !isPredictable(pin) else { throw PINError.tooPredictable }
    }

    /// The decoy PIN is only useful if it is a different secret: the same digits would unlock the
    /// real inbox and defeat the purpose.
    public static func validate(real: String, decoy: String) throws(PINError) {
        try validate(real)
        try validate(decoy)
        guard !constantTimeEquals(real, decoy) else { throw PINError.decoyMatchesReal }
    }

    /// Rejects one repeated digit and straight ascending or descending runs ("1234", "9876"), the
    /// guesses anyone tries first.
    static func isPredictable(_ pin: String) -> Bool {
        let digits = pin.compactMap(\.wholeNumberValue)
        guard digits.count == pin.count, let first = digits.first else { return true }
        if digits.allSatisfy({ $0 == first }) { return true }
        let ascending = zip(digits, digits.dropFirst()).allSatisfy { $1 == $0 + 1 }
        let descending = zip(digits, digits.dropFirst()).allSatisfy { $1 == $0 - 1 }
        return ascending || descending
    }

    /// Compares every byte regardless of where the first mismatch is, so timing does not leak how
    /// many leading digits were right. Length still leaks, which is acceptable for a 4–8 digit PIN.
    public static func constantTimeEquals(_ lhs: String, _ rhs: String) -> Bool {
        let left = Array(lhs.utf8)
        let right = Array(rhs.utf8)
        guard left.count == right.count else { return false }
        var difference: UInt8 = 0
        for (leftByte, rightByte) in zip(left, right) {
            difference |= leftByte ^ rightByte
        }
        return difference == 0
    }
}

/// Answers "which inbox does this PIN open?" without revealing whether a decoy exists at all: a
/// wrong PIN and a missing decoy both come back as nil. Production implementations hash the PINs
/// and keep them in the Keychain; the domain only fixes the contract.
public protocol PINVerifier: Sendable {
    func verify(_ pin: String) async -> AppLockMode?
}

/// Holds both PINs in memory. For previews and the DEBUG demo only; the real verifier never keeps
/// a PIN in a comparable form.
public struct StaticPINVerifier: PINVerifier {
    private let realPIN: String
    private let decoyPIN: String?

    public init(realPIN: String, decoyPIN: String?) {
        self.realPIN = realPIN
        self.decoyPIN = decoyPIN
    }

    public func verify(_ pin: String) async -> AppLockMode? {
        if PINRules.constantTimeEquals(pin, realPIN) { return .real }
        if let decoyPIN, PINRules.constantTimeEquals(pin, decoyPIN) { return .decoy }
        return nil
    }
}

/// Escalating delay after wrong guesses. Five free attempts cover honest typos; after that the wait
/// doubles-ish so an 8-digit space cannot be brute-forced on the device in any useful time.
public enum PINAttemptPolicy {
    public static let freeAttempts = 5

    /// Seconds the lock screen must refuse input after `failedAttempts` consecutive failures.
    public static func lockout(afterFailedAttempts failedAttempts: Int) -> TimeInterval {
        guard failedAttempts > freeAttempts else { return 0 }
        switch failedAttempts - freeAttempts {
        case 1: return 30
        case 2: return 60
        case 3: return 300
        case 4: return 900
        default: return 3_600
        }
    }

    /// Whether input is allowed at `now` given the last failure time and count.
    public static func canAttempt(failedAttempts: Int, lastFailureAt: Date?, now: Date) -> Bool {
        guard let lastFailureAt else { return true }
        let wait = lockout(afterFailedAttempts: failedAttempts)
        return now.timeIntervalSince(lastFailureAt) >= wait
    }
}
