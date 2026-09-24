#if DEBUG
import CipherCore
import Foundation
import os

/// The `--self-test echo <username> <password>` launch argument: a headless end-to-end check that the
/// whole stack works against a live relay. It signs the person in, brings Echo up, sends "ping" and
/// waits for a decrypted reply, then prints exactly one machine-readable line and exits with 0.
///
/// The process exits 0 either way; the verdict is the printed line, so a CI script greps for
/// `CIPHER_SELF_TEST PASS` rather than depending on how the simulator reports exit codes.
enum DemoBotSelfTest {
    struct Command: Hashable, Sendable {
        var target: String
        var username: String
        var password: String
    }

    enum Outcome: Hashable, Sendable {
        case pass(replyLength: Int, elapsedMillis: Int)
        case fail(reason: String)

        var line: String {
            switch self {
            case .pass(let replyLength, let elapsedMillis): "CIPHER_SELF_TEST PASS \(replyLength) \(elapsedMillis)"
            case .fail(let reason): "CIPHER_SELF_TEST FAIL \(reason)"
            }
        }

        var isPass: Bool {
            if case .pass = self { return true }
            return false
        }
    }

    static let flag = "--self-test"
    static let target = "echo"
    /// The reply budget promised to the caller, measured from the moment "ping" is handed to the stack.
    static let replyTimeout: TimeInterval = 20
    static let connectTimeout: TimeInterval = 15
    static let probe = "ping"

    /// Parses `--self-test echo <username> <password>` anywhere in the argument list.
    static func command(from arguments: [String] = CommandLine.arguments) -> Command? {
        guard let index = arguments.firstIndex(of: flag), arguments.count >= index + 4 else { return nil }
        let command = Command(target: arguments[index + 1], username: arguments[index + 2], password: arguments[index + 3])
        guard command.target == target, !command.username.isEmpty, !command.password.isEmpty else { return nil }
        return command
    }

    /// Prints the verdict on stdout (flushed, since the simulator's stdout is block-buffered) and to the
    /// unified log, then ends the process.
    static func report(_ outcome: Outcome) -> Never {
        let line = outcome.line
        print(line)
        fflush(stdout)
        DemoBotLog.selfTest.notice("\(line, privacy: .public)")
        os_log("%{public}@", log: OSLog(subsystem: "com.cipher.app", category: "demo.selftest"), type: .default, line)
        exit(0)
    }

    /// A single token for the FAIL line: the enum case for the bot's own errors, the type name for
    /// anything else, so the line never carries a sentence (or anything sensitive) from a description.
    static func reason(for error: any Error) -> String {
        if let failure = error as? DemoBotError {
            return String(describing: failure).split(separator: "(").first.map { String($0) } ?? String(describing: failure)
        }
        return String(describing: type(of: error))
    }
}
#endif
